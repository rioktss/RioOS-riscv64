# P4 Core/Driver Test Notes

The current shell-only build retains non-graphical checks for the VirtIO-MMIO discovery path, storage and network drivers, thread context switching, CPU topology defaults, and release ELF invariants. A successful host test pass is not a substitute for runtime verification under `qemu-system-riscv64`.
