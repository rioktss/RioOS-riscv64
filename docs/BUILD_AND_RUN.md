# Build and Run MyKernel RISC-V64

This source archive is the RISC-V 64 port of MyKernel. It builds a freestanding
RV64 kernel, three U-mode ELF programs, a MyFS disk image, and the host-side
regression tests. The intended machine is QEMU `virt`, with OpenSBI handing the
kernel off in supervisor mode.

## Requirements

- Clang and Clang++ with the `riscv64-unknown-elf` target
- LLD (`ld.lld`)
- Python 3, `readelf`, and `nm` for release verification
- QEMU's `qemu-system-riscv64` with OpenSBI firmware for runtime testing
- A desktop display backend (GTK or SDL) for the graphical UI

On Arch Linux, install the relevant `clang`, `lld`, `python`, `binutils`, and
QEMU packages. In Termux, the kernel can be cross-compiled with the available
Clang/LLD packages; QEMU system emulation may depend on the packages and device
support available for the particular Android environment.

## Build and test

```sh
chmod +x build.sh run.sh run-ui.sh
./build.sh --clean
```

The output is under `build/riscv64/`:

- `kernel.elf` — RV64 supervisor kernel, entry `0x80200000`
- `user_init.elf` — user-mode syscall smoke test
- `nano.elf` — basic terminal editor
- `calc.elf` — interactive calculator

The script also builds `storage/disk.img` and runs host regression tests and
`tests/verify_release.py`. The disk image and compiler outputs are generated
artifacts and are intentionally excluded from the source ZIP.

## Run in QEMU

Serial shell:

```sh
./run.sh
```

Graphical pixel UI:

```sh
./run-ui.sh
```

The graphical runner passes `ramfb`, VirtIO block/network, and VirtIO keyboard
and tablet devices to QEMU. The exact framebuffer/input behaviour should be
validated on the host's QEMU version; a successful cross-build alone does not
prove all device interactions work at runtime.

Helpful overrides:

```sh
RIOOS_MEM=256M RIOOS_SMP=1 ./run.sh
RIOOS_BIOS=/path/to/opensbi-fw_dynamic.bin ./run.sh
QEMU=/path/to/qemu-system-riscv64 ./run.sh
RIOOS_DISPLAY=sdl ./run-ui.sh
```

## What is ported

The source includes the RV64 boot path, supervisor trap frame and syscall entry,
Sv39 translation, U-mode transitions, SBI timer, 16550 UART, RTC, thread context
switching, shared filesystem/VFS, process metadata and ELF loading, file
descriptors and pipes, VirtIO block/network/input, UDP/DNS networking, pixel UI,
RPK package assets, diagnostics, and host regression tests. Features that depend
on specific firmware or virtual devices still require runtime testing on QEMU.
