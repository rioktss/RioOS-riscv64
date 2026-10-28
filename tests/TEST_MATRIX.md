# MyKernel RISC-V64 Test Matrix

## Automated by `./build.sh --clean`

- Clean freestanding RV64 build with `-Wall -Wextra -Werror`
- User ELF builds for init smoke test, nano editor, and calculator
- ELF64 little-endian `EM_RISCV` checks; kernel entry is `0x80200000`
- User `PT_LOAD` metadata and entry-point validation; no unresolved kernel symbols
- Static checks that RV64 trap/syscall, Sv39 MMU, U-mode transition, cooperative
  thread switch, descriptors, VirtIO, framebuffer and network functions are linked
- Filesystem host test: create/write/read/remount/delete, permission checks,
  owner/group/mode metadata, truncation and malformed-size rejection
- VFS host test: path handling, recursive remove, current-directory safety and
  writable user home
- Memory/page allocator, syscall, diagnostics, scheduler policy, environment,
  descriptor/pipe, process lifecycle and scheduler integration tests
- SMP default-state and spinlock tests; SMP stays disabled by default
- Framebuffer drawing, UI composition and image/settings persistence tests
- MyFS image generation and exact disk-image size check
- Python release verifier and strict shell exit on test failures

The release verifier does not claim a successful QEMU boot. The trap-entry code uses a direct RISC-V supervisor trap entry; it does not depend
on a fixed-size vector table.

## Required on a QEMU RISC-V64 host

- Run `./run.sh`; confirm the boot banner and interactive UART shell
- Exercise `help`, `version`, `uname`, `memory`, `mmu`, `irq`, `timer`, `threads`
  and `thread-demo` (cooperative thread switch only; periodic IRQ stays off by default)
- Exercise MyFS/VFS: `ls`, `cat`, `mkdir`, `touch`, `stat`, `chmod`, `nano`
  save/exit, copy/move, and persistence after reboot
- Exercise `exec /bin/init.elf` and the calculator ELF
- Exercise descriptors/pipes and shell environment/pipe/redirection commands
- Check VirtIO block and network with `disk`, `net`, `ping 10.0.2.2`, and
  `nslookup example.com`
- Run `./run-ui.sh` on a graphical QEMU build; verify rendering, keyboard/tablet
  input, app navigation, file manager, wallpaper selection and settings persistence

## Not implemented / limited

SMP, full preemptive process multitasking, `fork()`/`wait()`, descriptor
inheritance, TCP, DHCP, IPv6, IP fragment reassembly, dynamically loaded RPK
binaries, interrupt-driven VirtIO input and journaled filesystem transactions
are not part of this port. Timer IRQs are disabled during normal boot. Actual
QEMU disk, network and UI behaviour must be verified separately.
