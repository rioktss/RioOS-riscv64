# MyKernel / RioOS FAQ

## Is this Linux?

No. MyKernel is a freestanding kernel. QEMU and OpenSBI provide the guest's
virtual hardware and firmware handoff; no Linux userspace is involved.

## Which architecture does this archive target?

RISC-V 64-bit (RV64) on QEMU's `virt` machine, entering supervisor mode through
OpenSBI. The archive carries the RV64 boot, trap, timer, UART, MMU and context
switch implementation, plus the shared kernel subsystems.

## Do I need an ISO or GRUB?

No. `./build.sh` links an ELF kernel. `./run.sh` starts QEMU with OpenSBI and
loads `build/riscv64/kernel.elf` directly.

## What tools do I need?

Clang, Clang++, LLD, Python 3, `readelf` and `nm` for building and static
verification. To boot it, install `qemu-system-riscv64` with OpenSBI support.
A GTK/SDL display backend is also needed for `./run-ui.sh`.

## Can I run it on a physical RISC-V board?

Not as a drop-in image. The code currently targets QEMU `virt` memory addresses,
16550 UART, SBI TIME, QEMU ramfb/fw_cfg and VirtIO-MMIO. Real boards need board-
specific memory maps, firmware assumptions and device drivers.

## Is all runtime behaviour verified?

No. The build performs a freestanding RV64 link, host regression tests and ELF
static checks. Boot, user programs, framebuffer/input, storage and network
interaction must still be exercised on a compatible QEMU installation.

## Why keep this source public?

The project is intended for learning and experimentation with boot entry,
traps, virtual memory, syscalls, userspace ELF loading, a custom filesystem,
VirtIO and user/kernel transitions. See [LEARN.md](LEARN.md) and
[ARCHITECTURE.md](ARCHITECTURE.md).
