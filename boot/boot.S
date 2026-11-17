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

/*
 * MyKernel/RioOS RV64 bootstrap for QEMU virt.
 * QEMU's OpenSBI enters this ELF in supervisor mode:
 *   a0 = boot hart ID, a1 = device-tree blob (FDT) pointer.
 */
.section .text.boot,"ax",@progbits
.balign 4
.globl _start
.type _start,@function
.extern kernel_main
.extern __bss_start
.extern __bss_end
.extern __stack_top
.extern rioos_boot_hartid
.extern rioos_boot_dtb
.extern boot_dtb_ptr

_start:
    /* Preserve firmware arguments across BSS setup. */
    mv s0, a0
    mv s1, a1

    /* The current port is single-hart. OpenSBI normally starts hart 0. */
    bnez s0, .Lpark

    la sp, __stack_top
    andi sp, sp, -16

    /* Clear BSS before calling any C/C++ code. */
    la t0, __bss_start
    la t1, __bss_end
.Lclear_bss:
    bgeu t0, t1, .Lbss_done
    sd zero, 0(t0)
    addi t0, t0, 8
    j .Lclear_bss

.Lbss_done:
    la t0, rioos_boot_hartid
    sd s0, 0(t0)
    la t0, rioos_boot_dtb
    sd s1, 0(t0)
    la t0, boot_dtb_ptr
    sd s1, 0(t0)
    fence rw, rw

    call kernel_main

.Lpark:
    wfi
    j .Lpark
.size _start, .-_start

.section .stack,"aw",@nobits
.balign 4096
.globl __stack_bottom
__stack_bottom:
    .skip 16384
.globl __stack_top
__stack_top:
