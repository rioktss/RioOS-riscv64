#ifndef EXCEPTION_FRAME_H
#define EXCEPTION_FRAME_H

#include "types.h"

struct ExceptionFrame
{
#ifdef __riscv
    uint64_t x[32]; /* x[10..17] mirror a0..a7 for syscall dispatch */
#else
    uint64_t x[31];
#endif
    uint64_t elr;
    uint64_t spsr;
    uint64_t esr;
    uint64_t far;
    uint64_t padding;
#ifdef __riscv
    uint64_t padding2; /* The RV64 trap assembly allocates a 304-byte aligned frame. */
#endif
};

#ifdef __riscv
static_assert(sizeof(ExceptionFrame) == 304, "RV64 trap-frame size must match exceptions.S");
static_assert(__builtin_offsetof(ExceptionFrame, elr) == 256, "RV64 sepc offset mismatch");
static_assert(__builtin_offsetof(ExceptionFrame, spsr) == 264, "RV64 sstatus offset mismatch");
static_assert(__builtin_offsetof(ExceptionFrame, esr) == 272, "RV64 scause offset mismatch");
static_assert(__builtin_offsetof(ExceptionFrame, far) == 280, "RV64 stval offset mismatch");
#else
static_assert(sizeof(ExceptionFrame) == 288, "non-RISC-V fallback frame layout changed");
#endif

static inline int exception_from_el0(const ExceptionFrame* frame)
{
    if (frame == 0)
        return 0;

#ifdef __riscv
    return (frame->spsr & (1ULL << 8)) == 0; /* SPP=0: trap originated in U-mode */
#else
    return (frame->spsr & 0xFULL) == 0x0ULL ||
           (frame->spsr & 0xFULL) == 0x4ULL;
#endif
}

#endif
