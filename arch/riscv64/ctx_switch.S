/* RV64 cooperative kernel-thread context switch. */
.section .text,"ax",@progbits
.balign 4
.globl thread_context_switch
.globl thread_trampoline
.extern thread_entry_hook
.extern thread_exit

/* void thread_context_switch(uint64_t *old_sp_out, uint64_t new_sp)
   Preserve ra and s0-s11 (the RISC-V ABI callee-saved register set). */
thread_context_switch:
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
    sd sp, 0(a0)
    mv sp, a1
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

/* New-thread initial frame: s0=entry, s1=argument, ra=trampoline. */
thread_trampoline:
    call thread_entry_hook
    mv a0, s1
    jalr s0
    call thread_exit
.Lthread_dead:
    wfi
    j .Lthread_dead
