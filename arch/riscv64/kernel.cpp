#include <stdint.h>
#include <stddef.h>
#include "version.h"

extern "C" {
extern uint64_t rioos_boot_hartid;
extern uint64_t rioos_boot_dtb;
}

namespace {
void uart_put_dec(uint64_t value);

constexpr uintptr_t UART0 = 0x10000000UL; // QEMU virt 16550 UART
constexpr uintptr_t UART_RBR = 0;
constexpr uintptr_t UART_THR = 0;
constexpr uintptr_t UART_IER = 1;
constexpr uintptr_t UART_FCR = 2;
constexpr uintptr_t UART_LCR = 3;
constexpr uintptr_t UART_MCR = 4;
constexpr uintptr_t UART_LSR = 5;
constexpr uint8_t UART_LSR_DR = 0x01;
constexpr uint8_t UART_LSR_THRE = 0x20;
constexpr size_t LINE_CAPACITY = 160;

volatile uint8_t* const uart = reinterpret_cast<volatile uint8_t*>(UART0);

void uart_init() {
    // Standard QEMU virt UART clock is 3.6864 MHz; divisor 1 gives 115200 baud.
    uart[UART_IER] = 0x00;
    uart[UART_LCR] = 0x80; // divisor latch access
    uart[UART_THR] = 0x01; // divisor low
    uart[UART_IER] = 0x00; // divisor high
    uart[UART_LCR] = 0x03; // 8 data bits, no parity, one stop bit
    uart[UART_FCR] = 0x07; // enable and clear FIFOs
    uart[UART_MCR] = 0x03; // DTR + RTS
}

void uart_putc(char c) {
    if (c == '\n') uart_putc('\r');
    while ((uart[UART_LSR] & UART_LSR_THRE) == 0) {}
    uart[UART_THR] = static_cast<uint8_t>(c);
}

void uart_puts(const char* s) {
    if (!s) return;
    while (*s) uart_putc(*s++);
}

char uart_getc() {
    while ((uart[UART_LSR] & UART_LSR_DR) == 0) {}
    return static_cast<char>(uart[UART_RBR]);
}

bool streq(const char* a, const char* b) {
    if (!a || !b) return false;
    while (*a && *b && *a == *b) { ++a; ++b; }
    return *a == *b;
}

bool starts_with(const char* s, const char* prefix) {
    while (*prefix) {
        if (*s++ != *prefix++) return false;
    }
    return true;
}

void print_hex(uint64_t value) {
    static const char digits[] = "0123456789abcdef";
    uart_puts("0x");
    bool started = false;
    for (int shift = 60; shift >= 0; shift -= 4) {
        unsigned d = static_cast<unsigned>((value >> shift) & 0xfU);
        if (d || started || shift == 0) {
            uart_putc(digits[d]);
            started = true;
        }
    }
}

void clear_screen() {
    uart_puts("\x1b[2J\x1b[H");
}

void print_help() {
    uart_puts(
        "Commands available in the RISC-V bring-up shell:\n"
        "  help             Show this command list\n"
        "  about            Show RioOS project information\n"
        "  version          Show kernel version and target\n"
        "  uname            Show architecture/platform\n"
        "  cpu              Show boot hart ID\n"
        "  dtb              Show the device-tree address from firmware\n"
        "  memory           Show memory bring-up status\n"
        "  echo <text>      Print text\n"
        "  clear            Clear the terminal\n"
        "  reboot           Reboot through SBI, when supported\n"
        "  shutdown         Request shutdown through SBI, when supported\n"
        "  halt             Stop the current hart\n"
    );
}

/* SBI v0.2 System Reset extension. */
bool sbi_system_reset(unsigned long reset_type) {
    register unsigned long a0 asm("a0") = reset_type;
    register unsigned long a1 asm("a1") = 0; // reason: no specific reason
    register unsigned long a6 asm("a6") = 0; // function ID: system_reset
    register unsigned long a7 asm("a7") = 0x53525354UL; // SRST extension ID
    asm volatile("ecall"
                 : "+r"(a0), "+r"(a1)
                 : "r"(a6), "r"(a7)
                 : "memory");
    return a0 == 0;
}

void print_prompt() { uart_puts("rioos> "); }

void execute(char* line) {
    while (*line == ' ' || *line == '\t') ++line;
    if (*line == '\0') return;

    char* args = line;
    while (*args && *args != ' ' && *args != '\t') ++args;
    if (*args) {
        *args++ = '\0';
        while (*args == ' ' || *args == '\t') ++args;
    }

    if (streq(line, "help")) {
        print_help();
    } else if (streq(line, "about")) {
        uart_puts("RioOS is a small bare-metal OS project.\n"
                  "This target is the RISC-V 64 QEMU virt bring-up port.\n"
                  "The original AArch64 source tree is kept in this package.\n");
    } else if (streq(line, "version")) {
        uart_puts("RioOS kernel " MYKERNEL_VERSION_STRING "\n"
                  "Target: riscv64 / RV64IMAC / supervisor mode\n");
    } else if (streq(line, "uname")) {
        uart_puts("RioOS riscv64 qemu-virt supervisor\n");
    } else if (streq(line, "cpu")) {
        uart_puts("Boot hart ID: ");
        uart_put_dec(rioos_boot_hartid);
        uart_puts("\nSMP: one hart is started by this bring-up image\n");
    } else if (streq(line, "dtb")) {
        uart_puts("Firmware device-tree pointer: ");
        print_hex(rioos_boot_dtb);
        uart_putc('\n');
    } else if (streq(line, "memory")) {
        uart_puts("Kernel image: 0x80200000 (QEMU virt RAM)\n"
                  "Heap/page allocator: not initialized in this RISC-V bring-up port\n"
                  "QEMU RAM: configured by run.sh (default 128 MiB)\n");
    } else if (streq(line, "clear")) {
        clear_screen();
    } else if (streq(line, "echo")) {
        uart_puts(args);
        uart_putc('\n');
    } else if (streq(line, "reboot")) {
        uart_puts("Requesting SBI system reset...\n");
        (void)sbi_system_reset(1); // warm reboot
        uart_puts("SBI reset did not return a success response. Halting.\n");
        for (;;) asm volatile("wfi");
    } else if (streq(line, "shutdown")) {
        uart_puts("Requesting SBI shutdown...\n");
        (void)sbi_system_reset(0); // shutdown
        uart_puts("SBI shutdown did not return a success response. Halting.\n");
        for (;;) asm volatile("wfi");
    } else if (streq(line, "halt")) {
        uart_puts("RioOS halted. Reset the QEMU VM to boot again.\n");
        for (;;) asm volatile("wfi");
    } else if (streq(line, "")) {
        // Empty command.
    } else if (starts_with(line, "sudo")) {
        uart_puts("This bring-up port does not implement users or privilege escalation.\n");
    } else {
        uart_puts("Unknown command: ");
        uart_puts(line);
        uart_puts("\nType 'help' to list commands.\n");
    }
}

void uart_put_dec(uint64_t value) {
    char digits[24];
    size_t n = 0;
    if (value == 0) { uart_putc('0'); return; }
    while (value && n < sizeof(digits)) {
        digits[n++] = static_cast<char>('0' + (value % 10));
        value /= 10;
    }
    while (n) uart_putc(digits[--n]);
}

void shell_loop() {
    char line[LINE_CAPACITY];
    size_t length = 0;
    bool previous_was_cr = false;
    print_prompt();
    for (;;) {
        char c = uart_getc();
        if (c == '\n' && previous_was_cr) {
            previous_was_cr = false;
            continue;
        }
        if (c == '\r' || c == '\n') {
            previous_was_cr = (c == '\r');
            uart_putc('\n');
            line[length] = '\0';
            execute(line);
            length = 0;
            print_prompt();
        } else {
            previous_was_cr = false;
            if (c == '\b' || c == 0x7f) {
                if (length > 0) {
                    --length;
                    uart_puts("\b \b");
                }
            } else if (c >= 0x20 && c < 0x7f) {
                if (length + 1 < LINE_CAPACITY) {
                    line[length++] = c;
                    uart_putc(c);
                } else {
                    uart_putc('\a');
                }
            }
        }
    }
}
} // namespace

extern "C" {
uint64_t rioos_boot_hartid;
uint64_t rioos_boot_dtb;

void riscv64_kernel_main() {
    uart_init();
    uart_puts("\n\x1b[1;36m========================================\x1b[0m\n");
    uart_puts("\x1b[1;36m              RioOS v" MYKERNEL_VERSION_STRING "\x1b[0m\n");
    uart_puts("\x1b[1;36m========================================\x1b[0m\n");
    uart_puts("RISC-V 64 Bare-Metal Kernel\n");
    uart_puts("Platform : QEMU virt\n");
    uart_puts("Mode     : Supervisor (via OpenSBI)\n");
    uart_puts("UART     : 16550-compatible @ 0x10000000\n\n");
    uart_puts("RioOS RISC-V boot successful.\n");
    uart_puts("Type 'help' to get started.\n\n");
    shell_loop();
}
}
