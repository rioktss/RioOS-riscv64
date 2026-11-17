/*
 * MIT License
 *
 * Copyright (c) 2026 Rio okta kusuma
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files, to deal in the Software
 * without restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies of the
 * Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

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
