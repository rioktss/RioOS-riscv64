#include "mmu.h"
#include "uart.h"
#include "types.h"

namespace {
constexpr uint64_t PAGE = 4096ULL;
constexpr uint64_t PTE_V = 1ULL << 0;
constexpr uint64_t PTE_R = 1ULL << 1;
constexpr uint64_t PTE_W = 1ULL << 2;
constexpr uint64_t PTE_X = 1ULL << 3;
constexpr uint64_t PTE_U = 1ULL << 4;
constexpr uint64_t PTE_A = 1ULL << 6;
constexpr uint64_t PTE_D = 1ULL << 7;
constexpr uint64_t PTE_TABLE_FLAGS = PTE_V;
constexpr uint64_t IMAGE_PAGES = (MMU_USER_LIMIT - MMU_USER_BASE) / PAGE;
constexpr uint64_t STACK_PAGES = (MMU_USER_STACK_TOP - MMU_USER_STACK_BASE) / PAGE;
constexpr uint64_t TOTAL_USER_PAGES = IMAGE_PAGES + STACK_PAGES;
alignas(4096) uint64_t root[512];
alignas(4096) uint64_t l1_user[512];
alignas(4096) uint64_t user_l0[8][512];
alignas(4096) uint8_t user_frames[TOTAL_USER_PAGES][PAGE];
int enabled = 0;
int user_ready = 0;
int user_active = 0;
uint64_t pte(uint64_t pa, uint64_t flags) { return ((pa >> 12) << 10) | flags; }
uint64_t* pte_for(uint64_t va) {
    if (va < MMU_USER_BASE || va >= MMU_USER_STACK_TOP) return nullptr;
    const uint64_t l1_index = (va >> 21) & 0x1FFULL;
    const uint64_t l0_index = (va >> 12) & 0x1FFULL;
    if (l1_index < 56 || l1_index > 63) return nullptr;
    return &user_l0[l1_index - 56][l0_index];
}
uint64_t frame_index(uint64_t va) {
    if (va >= MMU_USER_BASE && va < MMU_USER_LIMIT) return (va - MMU_USER_BASE) / PAGE;
    return IMAGE_PAGES + (va - MMU_USER_STACK_BASE) / PAGE;
}
void flush_tlb() { asm volatile("sfence.vma x0, x0" ::: "memory"); }
}

void mmu_init() {
    for (uint64_t i = 0; i < 512; ++i) root[i] = 0;
    // Identity-map low MMIO space and QEMU RAM using Sv39 1-GiB leaves.
    root[0] = pte(0x00000000ULL, PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D);
    root[2] = pte(0x80000000ULL, PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D);
    root[1] = pte(reinterpret_cast<uint64_t>(l1_user), PTE_TABLE_FLAGS);
    for (uint64_t i = 0; i < 512; ++i) l1_user[i] = 0;
    for (uint64_t p = 0; p < 8; ++p) {
        l1_user[56 + p] = pte(reinterpret_cast<uint64_t>(user_l0[p]), PTE_TABLE_FLAGS);
        for (uint64_t i = 0; i < 512; ++i) user_l0[p][i] = 0;
    }
    const uint64_t satp = (8ULL << 60) | (reinterpret_cast<uint64_t>(root) >> 12);
    asm volatile("csrw satp, %0\nsfence.vma x0, x0\ncsrs sstatus, %1" :: "r"(satp), "r"(1ULL << 18) : "memory");
    enabled = 1;
    uart_puts("Sv39 address translation enabled (identity-mapped QEMU virt + user page tables).\r\n");
}
int mmu_enabled() { return enabled; }
uint64_t mmu_read_sctlr() { uint64_t value; asm volatile("csrr %0, sstatus" : "=r"(value)); return value; }
uint64_t mmu_read_ttbr0() { uint64_t value; asm volatile("csrr %0, satp" : "=r"(value)); return value; }
uint64_t mmu_read_tcr() { return 39ULL; }
void mmu_status() {
    uart_puts("MMU: Sv39; satp=0x");
    static const char hex[] = "0123456789ABCDEF";
    uint64_t value = mmu_read_ttbr0();
    for (int i = 15; i >= 0; --i) uart_putc(hex[(value >> (i * 4)) & 15]);
    uart_puts("\r\n");
}
int mmu_user_prepare() {
    for (uint64_t i = 0; i < TOTAL_USER_PAGES; ++i) {
        for (uint64_t j = 0; j < PAGE; ++j) user_frames[i][j] = 0;
    }
    for (uint64_t va = MMU_USER_BASE; va < MMU_USER_LIMIT; va += PAGE) {
        uint64_t* entry = pte_for(va); if (!entry) return -1;
        *entry = pte(reinterpret_cast<uint64_t>(user_frames[frame_index(va)]), PTE_V | PTE_R | PTE_W | PTE_A | PTE_D);
    }
    for (uint64_t va = MMU_USER_STACK_BASE; va < MMU_USER_STACK_TOP; va += PAGE) {
        uint64_t* entry = pte_for(va); if (!entry) return -1;
        *entry = pte(reinterpret_cast<uint64_t>(user_frames[frame_index(va)]), PTE_V | PTE_R | PTE_W | PTE_A | PTE_D);
    }
    user_ready = 1; user_active = 0; flush_tlb(); return 0;
}
int mmu_user_set_range(uint64_t start, uint64_t end, uint32_t flags) {
    if (!user_ready || start >= end || start < MMU_USER_BASE || end > MMU_USER_LIMIT) return -1;
    start &= ~(PAGE - 1);
    end = (end + PAGE - 1) & ~(PAGE - 1);
    if (end > MMU_USER_LIMIT || start >= end) return -1;
    uint64_t bits = PTE_V | PTE_U | PTE_A;
    if (flags & MMU_USER_READ) bits |= PTE_R;
    if (flags & MMU_USER_WRITE) bits |= PTE_W | PTE_D;
    if (flags & MMU_USER_EXEC) bits |= PTE_X;
    if (!(flags & (MMU_USER_READ | MMU_USER_WRITE | MMU_USER_EXEC))) return -1;
    if ((flags & MMU_USER_WRITE) && (flags & MMU_USER_EXEC)) return -1;
    for (uint64_t va = start; va < end; va += PAGE) { uint64_t* entry = pte_for(va); if (!entry) return -1; *entry = pte(reinterpret_cast<uint64_t>(user_frames[frame_index(va)]), bits); }
    flush_tlb(); return 0;
}
int mmu_user_finish() {
    if (!user_ready) return -1;
    for (uint64_t va = MMU_USER_STACK_BASE; va < MMU_USER_STACK_TOP; va += PAGE) {
        uint64_t* entry = pte_for(va); if (!entry) return -1;
        *entry = pte(reinterpret_cast<uint64_t>(user_frames[frame_index(va)]), PTE_V | PTE_R | PTE_W | PTE_U | PTE_A | PTE_D);
    }
    user_active = 1; flush_tlb(); return 0;
}
int mmu_user_pointer_ok(uint64_t address, uint64_t length, int write) {
    if (!length || address > ~0ULL - length) return 0;
    uint64_t end = address + length;
    if (address < MMU_USER_BASE || end > MMU_USER_LIMIT) return 0;
    if (!user_active) return 0;
    for (uint64_t va = address & ~(PAGE - 1); va < end; va += PAGE) {
        uint64_t* entry = pte_for(va); if (!entry || !(*entry & PTE_U)) return 0;
        if (write ? !(*entry & PTE_W) : !(*entry & (PTE_R | PTE_X))) return 0;
    }
    return 1;
}
uint64_t mmu_user_stack_top() { return MMU_USER_STACK_TOP; }
