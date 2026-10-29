# FAQ

## How do I build it?

Install Clang/Clang++, LLD, Python 3, `readelf`/`nm` equivalents, and QEMU RISC-V system emulation. From the repository root run `bash linux/build.sh`; choose the `termux`, `macos`, or `windows` folder on the corresponding host.

## How do I run the shell?

Use `bash linux/run.sh` to show the guest shell in the current terminal. Use `bash linux/run-terminal.sh` for a separate QEMU text-console window if your QEMU build includes a supported display backend. The Windows `.ps1` wrappers require Git Bash (`bash.exe` on `PATH`).

## Why doesn't QEMU networking always reach the internet?

The kernel includes VirtIO-Net and basic networking components, but connectivity depends on QEMU's user-mode network backend and the driver paths implemented in this learning project. Successful driver initialization alone does not guarantee complete internet connectivity.
