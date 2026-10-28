#include "timer.h"
#include "interrupt.h"
#include "scheduler.h"
#include "thread.h"

namespace {
constexpr uint64_t TIMEBASE_HZ = 10000000ULL;
constexpr long SBI_EXT_TIME = 0x54494D45L;
uint64_t tick_count = 0, irq_count = 0, stray_count = 0, oneshot_count = 0;
uint64_t period_ticks = 0, deadline = 0;
uint32_t mode = TIMER_MODE_OFF, current_hz = 0;
int sched_tick_enabled = 1;
uint64_t read_time() { uint64_t v; asm volatile("rdtime %0" : "=r"(v)); return v; }
int sbi_set_timer(uint64_t when) {
    register uint64_t a0 asm("a0") = when;
    register uint64_t a6 asm("a6") = 0;
    register uint64_t a7 asm("a7") = SBI_EXT_TIME;
    asm volatile("ecall" : "+r"(a0) : "r"(a6), "r"(a7) : "memory");
    return (int)a0;
}
void arm(uint64_t dt) { deadline = read_time() + (dt ? dt : 1); (void)sbi_set_timer(deadline); }
}
void timer_init() { tick_count = irq_count = stray_count = oneshot_count = 0; mode = TIMER_MODE_OFF; current_hz = 0; period_ticks = 0; deadline = 0; sbi_set_timer(~0ULL); }
void timer_start_periodic(uint32_t hz) { if (!hz) hz = 1; current_hz = hz; period_ticks = TIMEBASE_HZ / hz; if (!period_ticks) period_ticks = 1; mode = TIMER_MODE_PERIODIC; arm(period_ticks); }
void timer_stop() { mode = TIMER_MODE_OFF; current_hz = 0; period_ticks = 0; sbi_set_timer(~0ULL); }
void timer_start_oneshot_ms(uint32_t ms) { if (!ms) ms = 1; mode = TIMER_MODE_ONESHOT; current_hz = 0; uint64_t dt = (TIMEBASE_HZ * (uint64_t)ms) / 1000ULL; arm(dt ? dt : 1); }
void timer_set_sched_tick(int enabled) { sched_tick_enabled = enabled != 0; }
void timer_interrupt_handler() {
    if (mode == TIMER_MODE_OFF) { ++stray_count; return; }
    ++irq_count; ++tick_count;
    if (mode == TIMER_MODE_ONESHOT) { mode = TIMER_MODE_OFF; ++oneshot_count; sbi_set_timer(~0ULL); return; }
    arm(period_ticks);
    if (sched_tick_enabled) scheduler_tick();
    thread_timer_tick();
}
uint64_t timer_ticks() { return tick_count; }
uint64_t timer_frequency() { return TIMEBASE_HZ; }
uint64_t timer_millis() { return (read_time() * 1000ULL) / TIMEBASE_HZ; }
uint64_t timer_seconds() { return read_time() / TIMEBASE_HZ; }
void timer_delay_ms(uint64_t ms) { uint64_t end = read_time() + (TIMEBASE_HZ * ms) / 1000ULL; while ((int64_t)(read_time() - end) < 0) asm volatile("nop"); }
uint32_t timer_mode() { return mode; }
uint32_t timer_current_hz() { return current_hz; }
uint64_t timer_irq_count() { return irq_count; }
uint64_t timer_stray_count() { return stray_count; }
uint64_t timer_oneshot_fired() { return oneshot_count; }
