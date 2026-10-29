# Roadmap

This branch intentionally focuses on the text shell and kernel core. Current areas for improvement are:

- More complete QEMU RISC-V runtime acceptance testing on Linux, Termux, macOS, and Windows hosts.
- Broader serial/keyboard input regression coverage.
- More complete network protocol support and end-to-end tests.
- Filesystem crash-consistency and persistence tests.
- Clearer isolation and scheduling semantics for userspace programs and cooperative threads.
- Additional static checks for the RV64 ELF loader, syscall boundary, and driver error paths.

Graphical interfaces, framebuffer rendering, and GUI application packages are not part of this build target.
