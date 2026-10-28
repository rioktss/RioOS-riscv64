#include "interrupt.h"
#include "timer.h"
#include "uart.h"
#include "types.h"
namespace {
uint64_t total_irqs = 0, timer_irqs = 0, stray_irqs = 0, unhandled_irqs = 0, nested_irqs = 0;
uint32_t last_irq_id = 0, depth = 0, max_depth = 0;
inline uint64_t sstatus() { uint64_t v; asm volatile("csrr %0, sstatus" : "=r"(v)); return v; }
}
void interrupt_init() { asm volatile("csrw sie, zero\ncsrci sstatus, 2" ::: "memory"); total_irqs = timer_irqs = stray_irqs = unhandled_irqs = nested_irqs = 0; last_irq_id = depth = max_depth = 0; }
void interrupt_enable() { uint64_t bit = 32; asm volatile("csrs sie, %0\ncsrsi sstatus, 2" :: "r"(bit) : "memory"); }
void interrupt_disable() { asm volatile("csrci sstatus, 2" ::: "memory"); }
uint64_t interrupt_count() { return total_irqs; }
uint32_t interrupt_last_irq() { return last_irq_id; }
void interrupt_get_stats(InterruptStats* out) { if (!out) return; out->total=total_irqs; out->timer=timer_irqs; out->spurious=stray_irqs; out->unhandled=unhandled_irqs; out->nested=nested_irqs; out->last_irq=last_irq_id; out->max_depth=max_depth; }
int interrupt_cpu_irq_enabled() { return (sstatus() & 2ULL) != 0; }
void interrupt_timer_line_enable() { uint64_t bit = 32; asm volatile("csrs sie, %0" :: "r"(bit) : "memory"); }
void interrupt_timer_line_disable() { uint64_t bit = 32; asm volatile("csrc sie, %0" :: "r"(bit) : "memory"); }
extern "C" void interrupt_dispatch(ExceptionFrame* frame) {
    if (!frame) return;
    uint64_t cause = frame->esr;
    if (!(cause >> 63)) { ++unhandled_irqs; return; }
    uint64_t code = cause & 0x7FFFFFFFFFFFFFFFULL;
    ++depth; if (depth > max_depth) max_depth = depth;
    if (depth > 1) ++nested_irqs;
    ++total_irqs; last_irq_id = (uint32_t)code;
    if (code == 5) { ++timer_irqs; timer_interrupt_handler(); }
    else { ++unhandled_irqs; }
    --depth;
}
extern "C" void interrupt_exception(uint64_t cause, uint64_t pc, uint64_t fault, uint64_t status) {
    interrupt_disable();
    uart_puts("\r\nFATAL RISC-V trap: scause=0x");
    static const char h[]="0123456789ABCDEF";
    uint64_t vals[4]={cause,pc,fault,status}; const char* names[4]={" sepc=0x"," stval=0x"," sstatus=0x",""};
    for(int n=0;n<4;++n){ for(int i=15;i>=0;--i) uart_putc(h[(vals[n]>>(i*4))&15]); if(n<3) uart_puts(names[n]); }
    uart_puts("\r\nKernel halted.\r\n");
    for (;;) asm volatile("wfi");
}
