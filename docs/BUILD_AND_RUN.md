# Build and Run (RISC-V64)

RioOS is a freestanding RV64 kernel for QEMU `virt` and OpenSBI. It boots into the UART command shell. All interactive guest output is text-mode.

## Requirements

Install Clang/Clang++, LLD, Python 3, `readelf` (or `llvm-readelf`), `nm` (or `llvm-nm`), and QEMU with `qemu-system-riscv64` and OpenSBI support. On Windows, use the `.ps1` wrappers in `windows/`; they require Git for Windows (Git Bash) and its `bash.exe` on `PATH`.

## Build

Run the platform script from the repository root:

```sh
bash linux/build.sh --clean
```

Use `termux/build.sh` or `macos/build.sh` on the corresponding host; in Windows PowerShell, run `./windows/build.ps1`. The kernel and userspace ELF output is written to `build/riscv64/`. The 16 MiB filesystem image is generated at `storage/disk.img`.

## Run the shell

```sh
bash linux/run.sh
```

This launches QEMU in the current host terminal. To show the guest UART shell in a separate QEMU text-console window, use:

```sh
bash linux/run-terminal.sh
```

The separate-window runner displays a text serial console, not a guest desktop. Choose a supported QEMU display backend with `RIOOS_TERMINAL_DISPLAY` if needed. Termux's separate-window runner normally requires Termux:X11 and a QEMU build with SDL display support; `termux/run.sh` works directly in the Termux terminal.

## Kernel features

The build includes the kernel shell, command history/completion, terminal `nano` and `calc`, U-mode ELF loading/syscalls, MyFS/VFS, block and network drivers, diagnostics, process/thread primitives, and host regression tests.
