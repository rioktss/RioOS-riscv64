/* Minimal U-mode smoke test using the RV64 Linux-style a0-a5/a7 syscall ABI. */
.section .text,"ax",@progbits
.balign 4
.globl _start
.type _start,@function
_start:
    la a0, msg
    li a7, 1                  /* SYS_WRITE */
    ecall
    li a7, 2                  /* SYS_UPTIME */
    ecall
    li a7, 3                  /* SYS_GETPID */
    ecall
    li a0, 0
    li a7, 6                  /* SYS_EXIT */
    ecall
1:  j 1b
.size _start, .-_start
.section .rodata,"a",@progbits
.balign 8
msg:
    .asciz "[U-mode] MyKernel RISC-V64 userspace is alive.\r\n"
