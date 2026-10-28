# RISC-V 64 architecture layer

This is the architecture-specific layer for the MyKernel RV64 port. It targets
the QEMU `virt` board and enters in supervisor mode through OpenSBI.

| File | Responsibility |
| --- | --- |
| `boot.S` / `bootinfo.cpp` | OpenSBI entry, hart/DTB handoff, BSS clearing, stack setup |
| `exceptions.S` / `exceptions.cpp` | S-mode trap entry, saved register frame, syscall/fault dispatch |
| `mmu.cpp` | Sv39 page tables, kernel identity mappings, user image/stack mappings |
| `interrupt.cpp` / `timer.cpp` | Supervisor interrupt enables and SBI TIME scheduling timer |
| `uart.cpp` / `rtc.cpp` | 16550 UART and QEMU Goldfish RTC |
| `ctx_switch.S` / `user_entry.S` | Cooperative kernel-thread switch and U/S-mode entry/return |
| `user_init.S` | U-mode syscall smoke test |

Build with `./build.sh`; the generated kernel ELF is `build/riscv64/kernel.elf`.
The runtime target is `qemu-system-riscv64 -machine virt -bios default -kernel
build/riscv64/kernel.elf`. The standard `./run.sh` additionally attaches the
MyFS disk and VirtIO network device.

The port carries over the shared C++ subsystems and UI source. Host regression
checks and ELF/static checks are automated by the build script. Runtime testing
on a QEMU installation is still required to validate the full boot, U-mode,
framebuffer, and virtual-device paths end-to-end.
