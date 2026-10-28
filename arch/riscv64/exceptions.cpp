#include "exceptions.h"
#include "exception_frame.h"
#include "interrupt.h"
#include "syscall.h"
#include "fault.h"
#include "uart.h"
#include "mmu.h"
extern "C" void riscv64_trap_entry();
extern "C" void user_exit_return();
extern "C" void exceptions_init() {
    uint64_t vector = reinterpret_cast<uint64_t>(&riscv64_trap_entry);
    asm volatile("csrw stvec, %0\ncsrw sscratch, zero\ncsrw sie, zero\ncsrci sstatus, 2" :: "r"(vector) : "memory");
}
extern "C" void riscv64_trap_dispatch(ExceptionFrame* frame) {
    if (!frame) return;
    uint64_t scause = frame->esr;
    if (scause >> 63) { interrupt_dispatch(frame); return; }
    const uint64_t code = scause & 0x7FFFFFFFFFFFFFFFULL;
    const int from_user = (frame->spsr & (1ULL << 8)) == 0;
    if (code == 8 || code == 9) {
        frame->elr += 4;
        syscall_dispatch(frame, code == 8 ? 1 : 0);
        return;
    }
    if (from_user) {
        fault_report(scause, frame->elr, frame->far, frame->spsr);
        frame->x[10] = (uint64_t)-14;
        frame->spsr = (frame->spsr | (1ULL << 8)) & ~((1ULL << 1) | (1ULL << 5));
        frame->elr = reinterpret_cast<uint64_t>(&user_exit_return);
        frame->x[2] = reinterpret_cast<uint64_t>(frame) + sizeof(ExceptionFrame);
        return;
    }
    interrupt_exception(scause, frame->elr, frame->far, frame->spsr);
}
extern "C" void exception_sync_el1(void* raw) { riscv64_trap_dispatch(static_cast<ExceptionFrame*>(raw)); }
extern "C" void exception_sync_el0(void* raw) { riscv64_trap_dispatch(static_cast<ExceptionFrame*>(raw)); }
extern "C" void exception_irq_unhandled() { interrupt_disable(); for (;;) asm volatile("wfi"); }
