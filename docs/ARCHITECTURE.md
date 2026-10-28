# MyKernel RISC-V64 Architecture

This archive targets RV64GC-compatible integer code (`rv64imac_zicsr_zifencei`,
`lp64`) on QEMU's `virt` platform. The kernel is a freestanding ELF linked at
`0x80200000`, loaded by QEMU with OpenSBI firmware, and executes in supervisor
mode. It is not a Linux userspace application and does not use GRUB or an ISO.

## Boot flow

1. OpenSBI transfers control to `arch/riscv64/boot.S` with the boot hart in
   `a0` and the flattened device tree (FDT) pointer in `a1`.
2. The entry sets a per-kernel stack, records hart/FDT metadata, clears `.bss`,
   and calls `kernel_main()`.
3. `kernel/kernel.cpp` initializes UART, memory and page allocation, trap entry,
   the SBI timer, Sv39, block/network devices, MyFS/VFS, process metadata,
   input, scheduler, syscalls, and the UI/shell.
4. `run.sh` attaches a MyFS disk and VirtIO network interface. `run-ui.sh` also
   attaches ramfb and VirtIO input devices.

## Architecture files

| File | Purpose |
|---|---|
| `arch/riscv64/boot.S` | OpenSBI entry, BSS clearing, stack and boot argument handoff |
| `arch/riscv64/linker.ld` | RV64 linker layout and kernel symbols |
| `arch/riscv64/exceptions.S` | Supervisor trap prologue/epilogue and `sret` |
| `arch/riscv64/exceptions.cpp` | `scause` dispatch to syscalls, interrupts and fault paths |
| `include/exception_frame.h` | ABI layout for saved integer registers and supervisor CSRs |
| `arch/riscv64/mmu.cpp` | Sv39 root/intermediate tables, identity mappings and U-mode mappings |
| `arch/riscv64/timer.cpp` | SBI TIME timer programming and clock/tick queries |
| `arch/riscv64/interrupt.cpp` | `sie`/`sstatus` control and supervisor interrupt dispatch |
| `arch/riscv64/uart.cpp` | 16550 serial console driver |
| `arch/riscv64/rtc.cpp` | Read-only QEMU Goldfish RTC |
| `arch/riscv64/ctx_switch.S` | Cooperative kernel-thread switch preserving `ra` and `s0–s11` |
| `arch/riscv64/user_entry.S` | S-mode/U-mode transition and kernel register restoration |
| `arch/riscv64/user_init.S` | U-mode syscall smoke test |

## Exceptions and system calls

`arch/riscv64/exceptions.S` stores the integer-register frame and `sepc`,
`sstatus`, `scause`, and `stval`. U-mode `ecall` uses cause 8; S-mode `ecall`
uses cause 9. The syscall ABI follows the RV64 convention: arguments and return
value use `a0`–`a5`, and the syscall number uses `a7`. The dispatcher advances
`sepc` past the four-byte `ecall` instruction. `SYS_EXIT` and fatal U-mode
faults redirect the saved frame to `user_exit_return` and unwind to the saved
kernel stack.

`sscratch` stores the kernel stack pointer only while user mode is active. On
trap entry, the assembly switches stacks and then clears `sscratch` while the
kernel is executing, so a nested synchronous trap cannot accidentally treat the
interrupted user stack as a kernel stack.

## Sv39 and U-mode

`arch/riscv64/mmu.cpp` builds a three-level Sv39 page table. The kernel and
QEMU's low MMIO region are identity mapped; user image pages occupy
`0x47000000–0x477fffff`, and the user stack occupies `0x47f00000–0x47ffffff`.
The ELF loader checks `EM_RISCV`, verifies `PT_LOAD` ranges/permissions, rejects
writable-executable pages and overlapping permission pages, maps the segments,
and validates syscall buffer pointers before access.

## Memory, processes and threads

The kernel's heap begins at `__heap_start`. The page allocator is initialized
from a reserved heap chunk. Processes and the scheduler retain metadata and
lifecycle tracking; a fully preemptive process scheduler is not claimed. The
thread subsystem does implement cooperative CPU context switching using the
RV64 callee-saved ABI. The timer's scheduler tick and thread tick remain
quiescent during normal shell/userspace execution unless explicitly activated.

## I/O, file system and networking

VirtIO devices are located using the FDT passed by OpenSBI, with a QEMU `virt`
MMIO probing fallback. The block driver backs MyFS; VFS exposes path operations;
file descriptors provide process-local tables, shared open-file offsets,
duplicates and bounded pipes. The network stack includes Ethernet/ARP, IPv4,
ICMP echo, UDP datagrams, owner-scoped UDP sockets and DNS A lookup. Runtime
network connectivity depends on QEMU's user-mode network backend and must be
verified separately from compilation.

The framebuffer code programs QEMU's `ramfb` through fw_cfg and draws the boot
screen, lock/home screens, terminal, calculator, clock, files, launcher,
wallpaper and settings UIs. Keyboard/tablet events are polled through VirtIO
input. UART remains the fallback output/input path.

## Validation and known boundaries

`./build.sh --clean` compiles the kernel and userspace ELFs, creates the MyFS
image, runs host regression executables, and verifies RISC-V ELF metadata and
linked feature symbols. It does not boot QEMU as part of the default test pass.
For end-to-end acceptance, run `./run.sh` and exercise the shell, user ELF loader,
filesystem, descriptor/pipe functions, timer controls, VirtIO devices, and
`./run-ui.sh` on a host with suitable QEMU display/input support.
