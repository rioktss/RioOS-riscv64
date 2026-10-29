# P4 — Driver and SMP foundations

The shell-only branch retains the CPU-identification API, SMP default-state reporting, atomic spinlock primitives, VirtIO-Net receive-length validation, and host regression checks for core drivers.

## Safety limits

- No secondary CPU is released; the online CPU count remains one and SMP stays disabled.
- Spinlocks are primitives only and do not imply that all existing subsystems are SMP-safe.
- Timer IRQ remains disabled during normal boot.
- Host tests do not replace interactive QEMU boot validation.

## Validation

`linux/build.sh` builds the RV64 kernel and terminal userspace, runs non-graphical host tests, verifies the kernel ELF metadata, and checks that shell-only source and symbol checks pass. Runtime boot still requires a compatible `qemu-system-riscv64` installation.
