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
