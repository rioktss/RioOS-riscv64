# RISC-V 64 architecture layer

This is the architecture-specific layer for the MyKernel RV64 port. It targets the QEMU `virt` board and enters supervisor mode through OpenSBI.

| File | Responsibility |
| --- | --- |
| `boot/boot.S` / `bootinfo.cpp` | OpenSBI entry, hart/DTB handoff, BSS clearing, stack setup |
| `boot/exceptions.S` / `exceptions.cpp` | S-mode trap entry, saved register frame, syscall/fault dispatch |
| `mmu.cpp` | Sv39 page tables, kernel identity mappings, user image/stack mappings |
| `interrupt.cpp` / `timer.cpp` | Supervisor interrupt enables and SBI TIME scheduling timer |
| `uart.cpp` / `rtc.cpp` | 16550 UART and QEMU Goldfish RTC |
| `ctx_switch.S` / `user_entry.S` | Cooperative kernel-thread switch and U/S-mode entry/return |
| `user_init.S` | U-mode syscall smoke test |

The platform build scripts compile this layer with the shell and terminal-oriented drivers. The standard runtime attaches a MyFS disk and VirtIO network interface; all interactive console output is UART text.
