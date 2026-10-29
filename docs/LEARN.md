# Learning MyKernel RISC-V64

This guide follows the RV64 boot path and shared kernel subsystems. Build and run through the platform scripts in the repository root.

## Start with the whole system

```sh
bash linux/build.sh --clean
bash linux/run.sh
```

Try `help`, `version`, `uname`, `mem`, `mmu`, `irq`, `threads`, `ls`, `cat`, `mkdir`, `touch`, `chmod`, `exec`, `nano`, and `calc`. Some commands require the VirtIO disk/network devices attached by the runner.

## Source map

| Path | What to learn |
| --- | --- |
| `boot/boot.S` | OpenSBI handoff, BSS clearing and kernel stack |
| `boot/linker.ld` | Kernel memory layout at `0x80200000` |
| `boot/exceptions.S` | Trap entry/exit and saved register frame |
| `arch/riscv64/exceptions.cpp` | `scause` decode, syscall routing and user fault handling |
| `arch/riscv64/mmu.cpp` | Sv39 tables and U-mode address translation |
| `arch/riscv64/timer.cpp` | SBI TIME interface and software timer state |
| `arch/riscv64/interrupt.cpp` | Supervisor interrupt enables and dispatch |
| `arch/riscv64/uart.cpp` | 16550 UART I/O |
| `arch/riscv64/ctx_switch.S` | Cooperative thread context switch |
| `kernel/kernel.cpp` | Kernel initialization order |
| `kernel/shell.cpp`, `kernel/commands.cpp` | Interactive command parser and commands |
| `kernel/syscall.cpp`, `include/user_api.h` | Syscall ABI and U-mode API wrappers |
| `process/elf.cpp`, `process/user.cpp` | ELF validation/loading and user-program lifetime |
| `process/process.cpp`, `process/scheduler.cpp`, `process/thread.cpp` | Process metadata, scheduling and threads |
| `memory/memory.cpp`, `memory/page_alloc.cpp` | Heap and page allocator |
| `fs/fs.cpp`, `fs/vfs.cpp` | MyFS and virtual file system |
| `drivers/virtio_mmio.cpp`, `drivers/virtio_blk.cpp` | Virtual device discovery and block storage |
| `drivers/virtio_input.cpp`, `drivers/keyboard.cpp` | Text-shell keyboard input |
| `drivers/virtio_net.cpp`, `net/netstack.cpp` | Network driver and protocol stack |
| `userspace/nano.cpp`, `userspace/calc.cpp` | Example U-mode terminal programs |
| `tests/` | Host regression tests and static release verification |

## Suggested order

1. Read `boot/boot.S`, then `boot/linker.ld`.
2. Follow `kernel/kernel.cpp` and note the subsystem initialization order.
3. Read `include/exception_frame.h` and `boot/exceptions.S` together.
4. Follow an `ecall` from `include/user_api.h` into `kernel/syscall.cpp`.
5. Read `process/elf.cpp` and `arch/riscv64/mmu.cpp` to understand user-memory setup.
6. Explore `fs/`, `drivers/`, and `net/` after the kernel basics make sense.
7. Run `bash linux/build.sh --clean` after changes and add host tests for shared algorithms or filesystem/network behaviour.

## Scope and limitations

SMP is intentionally disabled; a single boot hart is used. Process scheduling is logical metadata rather than fully preemptive multi-process execution. Periodic interrupts remain off by default. Host tests do not replace interactive QEMU boot and runtime tests for keyboard, storage, and networking.
