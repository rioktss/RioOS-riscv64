# Shell-only Regression Test Matrix

`linux/build.sh` runs portable host tests for the filesystem, VFS, networking, memory/page allocator, syscalls/file descriptors, diagnostics, environment, process/scheduler policy, and SMP-state helpers. It then runs `tests/verify_release.py` to validate ELF metadata, required kernel symbols, shell presence, and the absence of UI sources.

Full runtime acceptance should also be checked with `qemu-system-riscv64`: boot to the UART prompt, verify command echo/editing/history/completion, execute `nano` and `calc`, test filesystem persistence, inspect VirtIO block/network diagnostics, and exercise the `selftest` command. The shell runner does not require or start guest graphics.
