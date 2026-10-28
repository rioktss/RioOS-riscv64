/*
 * RV64 supervisor trap entry. ExceptionFrame offsets are defined in
 * include/exception_frame.h. All integer registers are preserved. A trap
 * from U-mode switches to the kernel stack saved in sscratch; S-mode traps
 * remain on the current kernel stack.
 */
.section .text.vectors,"ax",@progbits
.balign 4
.globl exception_vectors_el1
.globl riscv64_trap_entry
.type exception_vectors_el1,@function
exception_vectors_el1:
riscv64_trap_entry:
    /* User entry: sp <- kernel stack, sscratch <- user sp.
       Supervisor entry: sp <- 0, so swap back without changing the stack. */
    csrrw sp, sscratch, sp
    bnez sp, .Lstack_ready
    csrrw sp, sscratch, sp
.Lstack_ready:
    addi sp, sp, -304

    /* x0..x31 (x0 is architecturally zero). */
    sd zero,   0(sp)
    sd ra,     8(sp)
    sd gp,    24(sp)
    sd tp,    32(sp)
    sd t0,    40(sp)
    sd t1,    48(sp)
    sd t2,    56(sp)
    sd s0,    64(sp)
    sd s1,    72(sp)
    sd a0,    80(sp)
    sd a1,    88(sp)
    sd a2,    96(sp)
    sd a3,   104(sp)
    sd a4,   112(sp)
    sd a5,   120(sp)
    sd a6,   128(sp)
    sd a7,   136(sp)
    sd s2,   144(sp)
    sd s3,   152(sp)
    sd s4,   160(sp)
    sd s5,   168(sp)
    sd s6,   176(sp)
    sd s7,   184(sp)
    sd s8,   192(sp)
    sd s9,   200(sp)
    sd s10,  208(sp)
    sd s11,  216(sp)
    sd t3,   224(sp)
    sd t4,   232(sp)
    sd t5,   240(sp)
    sd t6,   248(sp)

    /* Recover the interrupted sp without clobbering any unsaved GPR. */
    csrr t0, sscratch
    bnez t0, .Lsave_user_sp
    addi t0, sp, 304
.Lsave_user_sp:
    sd t0, 16(sp)
    /* Keep sscratch clear while executing in S-mode. Otherwise a nested
       synchronous trap could mistake the interrupted user SP for a kernel SP. */
    csrw sscratch, zero

    csrr t0, sepc
    sd t0, 256(sp)
    csrr t0, sstatus
    sd t0, 264(sp)
    csrr t0, scause
    sd t0, 272(sp)
    csrr t0, stval
    sd t0, 280(sp)
    sd zero, 288(sp)
    sd zero, 296(sp)

    mv a0, sp
    call riscv64_trap_dispatch

    /* The C dispatcher may edit sepc/sstatus and the saved return registers. */
    ld t0, 256(sp)
    csrw sepc, t0
    ld t0, 264(sp)
    csrw sstatus, t0

    /* sscratch is zero while the kernel runs, and holds the kernel stack top
       while U-mode runs. This makes the next trap's stack switch unambiguous. */
    ld t0, 264(sp)
    andi t0, t0, 256              /* sstatus.SPP: 1 = return to S-mode */
    bnez t0, .Lreturn_to_supervisor
    addi t0, sp, 304
    csrw sscratch, t0
    j .Lrestore_regs
.Lreturn_to_supervisor:
    csrw sscratch, zero

.Lrestore_regs:
    ld ra,     8(sp)
    ld gp,    24(sp)
    ld tp,    32(sp)
    ld t1,    48(sp)
    ld t2,    56(sp)
    ld s0,    64(sp)
    ld s1,    72(sp)
    ld a0,    80(sp)
    ld a1,    88(sp)
    ld a2,    96(sp)
    ld a3,   104(sp)
    ld a4,   112(sp)
    ld a5,   120(sp)
    ld a6,   128(sp)
    ld a7,   136(sp)
    ld s2,   144(sp)
    ld s3,   152(sp)
    ld s4,   160(sp)
    ld s5,   168(sp)
    ld s6,   176(sp)
    ld s7,   184(sp)
    ld s8,   192(sp)
    ld s9,   200(sp)
    ld s10,  208(sp)
    ld s11,  216(sp)
    ld t3,   224(sp)
    ld t4,   232(sp)
    ld t5,   240(sp)
    ld t6,   248(sp)
    ld t0,    40(sp)
    ld sp,    16(sp)
    sret
.size riscv64_trap_entry, .-riscv64_trap_entry
