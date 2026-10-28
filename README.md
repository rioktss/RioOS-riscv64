# MyKernel / RioOS — RISC-V 64

MyKernel is a freestanding operating-system learning project ported to **RISC-V 64 (RV64)**. This source-only package targets the **QEMU `virt` machine** and enters supervisor mode through OpenSBI. It includes a serial shell, Sv39 virtual memory, U-mode execution, persistent MyFS/VFS, VirtIO device drivers, networking primitives, diagnostics, a pixel UI, and host regression tests.

> **Port status:** the RV64 source compiles into a RISC-V ELF and the portable host regression tests run during `./build.sh`. Full boot and interactive QEMU acceptance testing must still be performed on a machine with `qemu-system-riscv64`; a compile pass by itself does not guarantee every firmware/device path works at runtime.

## Build and run

Requirements: Clang/Clang++, LLD, Python 3, `readelf`, and `nm`. QEMU/OpenSBI is needed to boot the kernel.

```sh
chmod +x build.sh run.sh run-ui.sh
./build.sh --clean
./run.sh
```

For the pixel framebuffer UI, launch from a desktop session with an appropriate QEMU display backend:

```sh
./run-ui.sh
```

`build.sh` produces `build/riscv64/kernel.elf`, `user_init.elf`, `nano.elf`, `calc.elf`, and `storage/disk.img`. Generated binaries and disk images are deliberately not included in the source ZIP.

See [Build and Run](docs/BUILD_AND_RUN.md), [Architecture](docs/ARCHITECTURE.md), and [RISC-V architecture layer](arch/riscv64/README.md).

## Feature map

| Subsystem | RV64 source implementation |
|---|---|
| Boot and platform | OpenSBI S-mode entry, hart ID + FDT handoff, kernel stack and BSS setup |
| Traps and syscalls | Saved RV64 register frame, `ecall`, U-mode/S-mode trap routing and fault reporting |
| Virtual memory | Sv39 page tables, kernel identity mapping, user image/stack pages and pointer validation |
| Time and interrupts | SBI TIME timer, supervisor timer interrupt handling, IRQ diagnostics; IRQs remain disabled by default |
| Execution | ELF64/RISC-V validation, U-mode entry/exit, process metadata and syscall boundary |
| Threads | Cooperative kernel-thread context switching using the RV64 callee-saved ABI |
| File system | MyFS, VFS, access permissions, ownership/mode metadata, truncation and persistent block image |
| File descriptors | Process-local descriptor tables, standard descriptors, open/read/write/seek/close, dup/dup2, bounded pipes |
| Storage | VirtIO-MMIO block device with filesystem image builder |
| Networking | VirtIO-Net plus ARP/IPv4/ICMP, UDP sockets, checksum validation and DNS A lookup |
| Input and display | 16550 UART, VirtIO input polling, QEMU `ramfb`, bitmap wallpaper/icons and pixel UI |
| User programs | U-mode syscall smoke test, terminal text editor, calculator |
| Developer tools | Diagnostics, shell environment/history, host tests and static release verifier |

## Important limits

- CPU startup currently keeps only the boot hart online; SMP remains disabled.
- Periodic timer interrupts are off by default to avoid asynchronous re-entry into the polled shell and userspace. The timer subsystem exposes periodic/one-shot control for testing.
- The process scheduler maintains logical process state; it is not full preemptive multi-process multitasking. The implemented CPU context switch is for cooperative kernel threads.
- The graphical UI, VirtIO input, block I/O, and network path must be exercised on the target QEMU build. Device model availability can differ by QEMU packaging/version.
- Unused legacy platform/bring-up files are removed; the RV64 build uses only `arch/riscv64/` for its architecture-specific entry, trap, timer, UART and MMU implementation.

## Repository layout

```text
arch/riscv64/   RV64 boot, trap, Sv39 MMU, SBI timer, UART, U-mode and context switch
include/        kernel interfaces and RV64 syscall ABI wrappers
kernel/         shell, syscall dispatch, security, descriptors, diagnostics
memory/         heap/page allocator and shared memory metadata
process/        ELF loader, process metadata, scheduler and threads
fs/             MyFS and VFS
net/            network stack
drivers/        VirtIO block/network/input, framebuffer and fonts
ui/             RioOS pixel UI and built-in applications
userspace/      nano, calculator and ELF linker script
apps/           installed RPK manifests
assets/         local bitmap wallpaper and icons
tests/          host regression tests and release checks
docs/           build, architecture and subsystem notes
```

The project is distributed under the MIT license. See [LICENSE](LICENSE).
