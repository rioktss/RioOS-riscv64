#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

QEMU="${QEMU:-qemu-system-riscv64}"
MEM="${RIOOS_MEM:-128M}"
SMP="${RIOOS_SMP:-1}"
BIOS="${RIOOS_BIOS:-default}"
DISPLAY_BACKEND="${RIOOS_DISPLAY:-gtk}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'HELP'
MyKernel RISC-V64 graphical runner
Usage: ./run-ui.sh
Environment: QEMU, RIOOS_MEM (128M), RIOOS_SMP (1), RIOOS_BIOS (default), RIOOS_DISPLAY (gtk or sdl)
The kernel is built automatically when build artifacts are missing or stale.
HELP
    exit 0
fi

stale=0
if [[ ! -s build/riscv64/kernel.elf || ! -s storage/disk.img ]]; then
    stale=1
elif find arch include kernel process memory fs net drivers ui userspace apps assets tests -type f -newer build/riscv64/kernel.elf -print -quit | grep -q .; then
    stale=1
elif [[ build.sh -nt build/riscv64/kernel.elf ]]; then
    stale=1
fi
if (( stale )); then ./build.sh; fi

command -v "$QEMU" >/dev/null 2>&1 || {
    echo "ERROR: '$QEMU' was not found. Install QEMU system emulation for RISC-V 64." >&2
    exit 1
}
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" && "$DISPLAY_BACKEND" =~ ^(gtk|sdl)$ ]]; then
    echo "ERROR: no graphical session; run inside a desktop session or use ./run.sh." >&2
    exit 1
fi
backend_ok() { "$QEMU" -display help 2>&1 | grep -qw -- "$1"; }
if ! backend_ok "$DISPLAY_BACKEND"; then
    picked=""
    for candidate in gtk sdl; do
        if backend_ok "$candidate"; then picked="$candidate"; break; fi
    done
    if [[ -z "$picked" ]]; then
        echo "ERROR: no usable '$DISPLAY_BACKEND', gtk, or sdl display backend in this QEMU." >&2
        exit 1
    fi
    echo "NOTE: display backend '$DISPLAY_BACKEND' unavailable; using '$picked'." >&2
    DISPLAY_BACKEND="$picked"
fi
DEVICE_HELP="$("$QEMU" -device help 2>&1 || true)"
for required_device in ramfb virtio-keyboard-device virtio-tablet-device; do
    if ! grep -Fq "name \"${required_device}\"" <<<"$DEVICE_HELP"; then
        echo "ERROR: this QEMU build lacks '${required_device}'." >&2
        exit 1
    fi
done

printf 'MyKernel RISC-V64 graphical UI on QEMU (%s).\n' "$DISPLAY_BACKEND" >&2
printf 'UART remains connected here; keyboard/mouse input is provided by VirtIO.\n' >&2
exec "$QEMU" \
    -machine virt \
    -m "$MEM" \
    -smp "$SMP" \
    -bios "$BIOS" \
    -display "$DISPLAY_BACKEND" \
    -serial stdio \
    -monitor none \
    -global virtio-mmio.force-legacy=false \
    -kernel build/riscv64/kernel.elf \
    -device ramfb \
    -drive if=none,format=raw,file=storage/disk.img,id=vd0 \
    -device virtio-blk-device,drive=vd0 \
    -netdev user,id=n1,ipv4=on,ipv6=off \
    -device virtio-net-device,netdev=n1 \
    -device virtio-keyboard-device \
    -device virtio-tablet-device
