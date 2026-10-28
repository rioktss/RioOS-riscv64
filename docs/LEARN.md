# Learning MyKernel RISC-V64

This guide follows the RV64 boot path and the shared kernel subsystems. You can
build from Termux or a Linux/macOS/WSL development environment with Clang/LLD.
A compatible QEMU system emulator is required for booting the kernel.

## Start with the whole system

```sh
./build.sh --clean
./run.sh
```

Try `help`, `version`, `uname`, `memory`, `mmu`, `irq`, `timer`, `threads`,
`ls`, `cat`, `mkdir`, `touch`, `stat`, `chmod`, `exec`, and other commands that
appear in the shell's `help` output. Some commands require a VirtIO disk/network
device attached by the runner.

## Source map

| Path | What to learn |
|---|---|
| `arch/riscv64/boot.S` | OpenSBI handoff, BSS clearing and kernel stack |
| `arch/riscv64/linker.ld` | Kernel memory layout at `0x80200000` |
| `arch/riscv64/exceptions.S` | Trap entry/exit and saved register frame |
| `arch/riscv64/exceptions.cpp` | `scause` decode, syscall routing and user fault handling |
| `arch/riscv64/mmu.cpp` | Sv39 tables and U-mode address translation |
| `arch/riscv64/timer.cpp` | SBI TIME interface and software timer state |
| `arch/riscv64/interrupt.cpp` | Supervisor interrupt enables and dispatch |
| `arch/riscv64/uart.cpp` | 16550 UART I/O |
| `arch/riscv64/ctx_switch.S` | Cooperative thread context switch |
| `arch/riscv64/user_entry.S` | U-mode entry and kernel-stack restoration |
| `kernel/kernel.cpp` | Kernel initialization order |
| `kernel/shell.cpp`, `kernel/commands.cpp` | Interactive command parser and commands |
| `kernel/syscall.cpp`, `include/user_api.h` | Syscall ABI and U-mode API wrappers |
| `process/elf.cpp`, `process/user.cpp` | ELF validation/loading and user-program lifetime |
| `process/process.cpp`, `process/scheduler.cpp`, `process/thread.cpp` | Process metadata, scheduling and threads |
| `memory/memory.cpp`, `memory/page_alloc.cpp` | Heap and page allocator |
| `fs/fs.cpp`, `fs/vfs.cpp` | MyFS and virtual file system |
| `drivers/virtio_mmio.cpp`, `drivers/virtio_blk.cpp` | Virtual device discovery and block storage |
| `drivers/virtio_net.cpp`, `net/netstack.cpp` | Network driver and protocol stack |
| `drivers/fb.cpp`, `ui/` | Framebuffer and graphical shell/apps |
| `userspace/nano.cpp`, `userspace/calc.cpp` | Example U-mode applications |
| `tests/` | Host regression tests and static release verification |

## Suggested order

1. Read `arch/riscv64/boot.S`, then `arch/riscv64/linker.ld`.
2. Follow `kernel/kernel.cpp` and note the dependency order of subsystems.
3. Read `include/exception_frame.h` and `arch/riscv64/exceptions.S` together.
4. Follow an `ecall` from `include/user_api.h` into `kernel/syscall.cpp`.
5. Read `process/elf.cpp` and `arch/riscv64/mmu.cpp` to understand user-memory setup.
6. Explore `fs/`, `drivers/`, and `net/` after the kernel basics make sense.
7. Run `./build.sh --clean` after each change. Add or update a host regression
   test when changing shared algorithms or filesystem/network behaviour.

## Concepts demonstrated

- RISC-V supervisor/user privilege and trap return
- ELF64 program headers and permission boundaries
- Sv39 page tables and user pointers
- System-call ABI and synchronous user-mode process lifetime
- Cooperative context switching and thread stacks
- Custom filesystem metadata and access permissions
- VirtIO-MMIO devices and bounded networking structures
- Freestanding C++ without exceptions, RTTI, or a normal C++ runtime

## Scope and limitations

SMP is intentionally disabled; a single boot hart is used. Process scheduling is
logical metadata rather than fully preemptive multi-process execution. Periodic
interrupts remain off by default. QEMU boot, display input, storage and actual
network packet exchange need separate runtime acceptance testing.
