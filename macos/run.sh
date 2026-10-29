#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

QEMU="${QEMU:-qemu-system-riscv64}"
KERNEL="${KERNEL:-build/riscv64/kernel.elf}"
DISK="${DISK:-storage/disk.img}"
MEM="${RIOOS_MEM:-128M}"
SMP="${RIOOS_SMP:-1}"
BIOS="${RIOOS_BIOS:-default}"

if [[ "${1:-}" == '-h' || "${1:-}" == '--help' ]]; then
    cat <<'HELP'
Run RioOS shell in the current host terminal.
Builds automatically if the kernel or filesystem image is missing/stale.
Environment: QEMU, KERNEL, DISK, RIOOS_MEM, RIOOS_SMP, RIOOS_BIOS.
Exit: Ctrl+C, or Ctrl+A then X when QEMU's nographic mode supports it.
HELP
    exit 0
fi

stale=0
if [[ ! -s "$KERNEL" || ! -s "$DISK" ]]; then
    stale=1
elif [[ "$KERNEL" == 'build/riscv64/kernel.elf' ]] && find boot arch include kernel process memory fs net drivers userspace tests -type f -newer "$KERNEL" -print -quit | grep -q .; then
    stale=1
elif [[ "$SCRIPT_DIR/build.sh" -nt "$KERNEL" ]]; then
    stale=1
fi
if (( stale )); then
    echo 'RioOS build artifacts missing or stale; building shell-only image...'
    bash "$SCRIPT_DIR/build.sh"
fi
command -v "$QEMU" >/dev/null 2>&1 || {
    printf "ERROR: '%s' was not found. Install qemu-system-riscv64 with OpenSBI support.\n" "$QEMU" >&2
    exit 1
}
[[ -s "$KERNEL" ]] || { printf 'ERROR: kernel ELF not found: %s\n' "$KERNEL" >&2; exit 1; }
[[ -s "$DISK" ]] || { printf 'ERROR: MyFS image not found: %s\n' "$DISK" >&2; exit 1; }

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
