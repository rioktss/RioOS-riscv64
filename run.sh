#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

QEMU="${QEMU:-qemu-system-riscv64}"
KERNEL="${KERNEL:-build/riscv64/kernel.elf}"
DISK="${DISK:-storage/disk.img}"
MEM="${RIOOS_MEM:-128M}"
SMP="${RIOOS_SMP:-1}"
BIOS="${RIOOS_BIOS:-default}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'HELP'
MyKernel RISC-V64 UART runner
Usage: ./run.sh
Environment: QEMU, KERNEL, DISK, RIOOS_MEM (128M), RIOOS_SMP (1), RIOOS_BIOS (default)
Builds the source if the kernel or a source input is newer than the ELF.
Exit QEMU with Ctrl+A, then X when using the nographic terminal.
HELP
    exit 0
fi

stale=0
if [[ ! -s "$KERNEL" || ! -s "$DISK" ]]; then
    stale=1
elif [[ "$KERNEL" == "build/riscv64/kernel.elf" ]] && find arch include kernel process memory fs net drivers ui userspace apps assets tests -type f -newer "$KERNEL" -print -quit | grep -q .; then
    stale=1
elif [[ build.sh -nt "$KERNEL" ]]; then
    stale=1
fi
if (( stale )); then
    echo "RISC-V64 build artifacts missing or stale; building..."
    ./build.sh
fi

command -v "$QEMU" >/dev/null 2>&1 || {
    echo "ERROR: '$QEMU' was not found. Install qemu-system-riscv64 with OpenSBI support." >&2
    exit 1
}
[[ -s "$KERNEL" ]] || { echo "ERROR: kernel ELF not found: $KERNEL" >&2; exit 1; }
[[ -s "$DISK" ]] || { echo "ERROR: MyFS image not found: $DISK" >&2; exit 1; }

exec "$QEMU" \
    -machine virt \
    -m "$MEM" \
    -smp "$SMP" \
    -bios "$BIOS" \
    -kernel "$KERNEL" \
    -nographic \
    -serial stdio \
    -monitor none \
    -global virtio-mmio.force-legacy=false \
    -drive "if=none,format=raw,file=$DISK,id=vd0" \
    -device virtio-blk-device,drive=vd0 \
    -netdev user,id=n1,ipv4=on,ipv6=off \
    -device virtio-net-device,netdev=n1
