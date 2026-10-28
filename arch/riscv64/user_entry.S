/* Switch between S-mode and a single isolated U-mode task. */
.section .text.user_entry,"ax",@progbits
.balign 4
.globl user_enter
.globl user_exit_return

/* user_enter(entry=a0, stack_top=a1). Save all ABI callee-saved state on the
   kernel stack, point sscratch at that kernel stack, and enter U-mode. */
user_enter:
    addi sp, sp, -112
    sd ra,   0(sp)
    sd s0,   8(sp)
    sd s1,  16(sp)
    sd s2,  24(sp)
    sd s3,  32(sp)
    sd s4,  40(sp)
    sd s5,  48(sp)
    sd s6,  56(sp)
    sd s7,  64(sp)
    sd s8,  72(sp)
    sd s9,  80(sp)
    sd s10, 88(sp)
    sd s11, 96(sp)
    sd zero,104(sp)

    mv t0, a0
    mv t1, a1
    csrw sscratch, sp
    csrw sepc, t0
    csrr t2, sstatus
    li t3, 0x122             /* SPP | SIE | SPIE */
    not t3, t3
    and t2, t2, t3           /* return privilege U; keep interrupts disabled */
    csrw sstatus, t2
    mv sp, t1

    /* Do not leak kernel pointers or values into the new process. */
    li ra, 0
    li gp, 0
    li tp, 0
    li t0, 0
    li t1, 0
    li t2, 0
    li t3, 0
    li t4, 0
    li t5, 0
    li t6, 0
    li s0, 0
    li s1, 0
    li s2, 0
    li s3, 0
    li s4, 0
    li s5, 0
    li s6, 0
    li s7, 0
    li s8, 0
    li s9, 0
    li s10, 0
    li s11, 0
    li a0, 0
    li a1, 0
    li a2, 0
    li a3, 0
    li a4, 0
    li a5, 0
    li a6, 0
    li a7, 0
    sret

/* The trap dispatcher redirects SYS_EXIT/fatal U-mode faults here with
   x2 set to the kernel stack pointer just above the save frame. */
user_exit_return:
    ld ra,   0(sp)
    ld s0,   8(sp)
    ld s1,  16(sp)
    ld s2,  24(sp)
    ld s3,  32(sp)
    ld s4,  40(sp)
    ld s5,  48(sp)
    ld s6,  56(sp)
    ld s7,  64(sp)
    ld s8,  72(sp)
    ld s9,  80(sp)
    ld s10, 88(sp)
    ld s11, 96(sp)
    addi sp, sp, 112
    ret
