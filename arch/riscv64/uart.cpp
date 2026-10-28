#include "uart.h"
#include "types.h"

namespace {
constexpr uint64_t UART_BASE = 0x10000000UL;
constexpr uint64_t RBR_THR_DLL = 0;
constexpr uint64_t IER_DLM = 1;
constexpr uint64_t FCR = 2;
constexpr uint64_t LCR = 3;
constexpr uint64_t MCR = 4;
constexpr uint64_t LSR = 5;
constexpr uint8_t LSR_DATA_READY = 1U;
constexpr uint8_t LSR_THR_EMPTY = 0x20U;
uart_output_hook_t output_hook = nullptr;
uart_output_flush_hook_t flush_hook = nullptr;
int mirror_serial = 1;
inline volatile uint8_t& reg(uint64_t offset) { return *reinterpret_cast<volatile uint8_t*>(UART_BASE + offset); }
void serial_putc(char c) {
    unsigned long spin = 1000000;
    while ((reg(LSR) & LSR_THR_EMPTY) == 0 && --spin) {}
    reg(RBR_THR_DLL) = static_cast<uint8_t>(c);
}
}

void uart_putc(char c) {
    if (output_hook) {
        output_hook(c);
        if (!mirror_serial) return;
    }
    serial_putc(c);
}
void uart_puts(const char* s) { if (!s) return; while (*s) uart_putc(*s++); }
int uart_try_getc() { if (!(reg(LSR) & LSR_DATA_READY)) return -1; return reg(RBR_THR_DLL); }
int uart_has_data() { return (reg(LSR) & LSR_DATA_READY) != 0; }
char uart_getc() { int c; while ((c = uart_try_getc()) < 0) asm volatile("nop"); return static_cast<char>(c); }
void uart_set_output_hook(uart_output_hook_t hook, int mirror) { output_hook = hook; mirror_serial = mirror != 0; }
void uart_clear_output_hook() { output_hook = nullptr; mirror_serial = 1; }
int uart_output_hook_active() { return output_hook != nullptr; }
void uart_set_output_flush_hook(uart_output_flush_hook_t hook) { flush_hook = hook; }
void uart_flush_output() { if (flush_hook) flush_hook(); asm volatile("fence iorw, iorw" ::: "memory"); }
extern "C" void riscv64_uart_init() {
    reg(IER_DLM) = 0;
    reg(LCR) = 0x80;
    reg(RBR_THR_DLL) = 1;
    reg(IER_DLM) = 0;
    reg(LCR) = 0x03;
    reg(FCR) = 0x07;
    reg(MCR) = 0x03;
}
