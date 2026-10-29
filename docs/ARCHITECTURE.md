# Architecture Overview

MyKernel/RioOS is a freestanding RISC-V 64 operating-system learning project. This tree builds for QEMU `virt`, enters supervisor mode via OpenSBI, and boots directly into a UART command shell. No framebuffer, guest GUI, launcher, or graphical app package is present.

## Boot path

1. `boot/boot.S` preserves the firmware hart/FDT values, clears BSS, sets the kernel stack, and calls `kernel_main`.
2. `kernel/kernel.cpp` initializes CPU topology, memory, page allocation, exceptions, timer, Sv39 MMU, VirtIO storage/network, MyFS/VFS, process/security state, keyboard input, scheduler/thread support, interrupts, and syscalls.
3. `kernel/shell.cpp` starts the interactive UART shell. The ordinary runner maps this serial shell to the current host terminal.
4. `userspace/` supplies the init smoke test, terminal editor, calculator, and their ELF linker/entry files. These are text-mode programs, not GUI applications.

## Core subsystems

- `arch/riscv64/`: boot, traps, timer, UART, MMU, and architecture-specific entry code.
- `kernel/`: command handling, shell, history, environment, diagnostics, security, syscalls, and version info.
- `memory/` and `process/`: heap/page allocation, ELF loading, process metadata, scheduler, and cooperative threads.
- `fs/`: persistent MyFS image support and VFS.
- `drivers/`: UART, keyboard input, VirtIO-MMIO, block, and network drivers.
- `net/`: ARP/IPv4/ICMP, UDP, and DNS functionality.
- `tests/`: non-graphical host regression tests and static release verification.

## Runtime policy

The default boot is text-only. `linux/run.sh` (or its platform counterpart) uses QEMU's nographic serial mode. `run-terminal.sh` opens a separate QEMU text-console window on hosts with a supported display backend, but does not start any guest graphics. Timer preemption remains disabled by default, and only the boot hart is started.
