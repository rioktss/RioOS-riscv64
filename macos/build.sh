#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

VERBOSE=0
CLEAN=0
RUN_AFTER_BUILD=0
for arg in "$@"; do
    case "$arg" in
        -v|--verbose) VERBOSE=1 ;;
        --clean) CLEAN=1 ;;
        --run) RUN_AFTER_BUILD=1 ;;
        -h|--help)
            cat <<'HELP'
MyKernel / RioOS RISC-V64 shell-only build
Usage: build.sh [--clean] [--verbose] [--run]
Builds the RISC-V kernel, terminal userspace tools, MyFS image, and host tests.
No GUI, framebuffer frontend, or graphical app packages are built.
HELP
            exit 0 ;;
        *) printf 'ERROR: unknown argument: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

CLANG="${CLANG:-clang}"
CXX="${CXX:-clang++}"
LD="${LD:-ld.lld}"
PYTHON="${PYTHON:-python3}"
if command -v readelf >/dev/null 2>&1; then
    READELF="${READELF:-readelf}"
else
    READELF="${READELF:-llvm-readelf}"
fi
OUT="build/riscv64"
HOST_TOOLS="${MYKERNEL_TOOLS_DIR:-$HOME/.mykernel-tools}"

for tool in "$CLANG" "$CXX" "$LD" "$PYTHON" "$READELF"; do
    command -v "$tool" >/dev/null 2>&1 || {
        printf "ERROR: required tool '%s' not found\n" "$tool" >&2
        exit 1
    }
done
if [[ "$CLEAN" -eq 1 ]]; then
    rm -rf build
    rm -f storage/disk.img
fi
mkdir -p "$OUT" storage storage/home "$HOST_TOOLS"

TARGET_FLAGS=(--target=riscv64-unknown-elf -march=rv64imac_zicsr_zifencei -mabi=lp64 -mcmodel=medany)
CXXFLAGS=("${TARGET_FLAGS[@]}" -Iinclude -std=c++17 -O1 -ffreestanding -fno-builtin -fno-stack-protector -fno-pic -fno-pie -fno-vectorize -fno-slp-vectorize -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions -fno-rtti -fno-threadsafe-statics -fno-use-cxa-atexit -fdata-sections -ffunction-sections -nostdlib -nostdinc++ -Wall -Wextra -Werror)
ASMFLAGS=("${TARGET_FLAGS[@]}" -ffreestanding -fno-pic -fno-pie -Iinclude)
USERFLAGS=("${TARGET_FLAGS[@]}" -Iinclude -std=c++17 -O1 -ffreestanding -fno-builtin -fno-stack-protector -fno-pic -fno-pie -fno-vectorize -fno-slp-vectorize -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions -fno-rtti -fno-threadsafe-statics -fno-use-cxa-atexit -ffunction-sections -fdata-sections -nostdlib -nostdinc++ -Wall -Wextra -Werror)

log() { printf '[%s] %s\n' "$1" "$2"; }
compile_cpp() {
    local name="$1" src="$2"
    [[ -f "$src" ]] || { printf 'ERROR: missing source %s\n' "$src" >&2; exit 1; }
    [[ "$VERBOSE" -eq 1 ]] && printf '  CXX %s\n' "$src"
    "$CXX" "${CXXFLAGS[@]}" -c "$src" -o "$OUT/$name.o"
}
compile_asm() {
    local name="$1" src="$2"
    [[ -f "$src" ]] || { printf 'ERROR: missing assembly source %s\n' "$src" >&2; exit 1; }
    [[ "$VERBOSE" -eq 1 ]] && printf '  AS  %s\n' "$src"
    "$CLANG" "${ASMFLAGS[@]}" -c "$src" -o "$OUT/$name.o"
}

log 1 'Building terminal userspace (init, nano, calculator)'
compile_asm user_init arch/riscv64/user_init.S
"$LD" -m elf64lriscv -T userspace/user_init.ld --build-id=none "$OUT/user_init.o" -o "$OUT/user_init.elf"
"$CXX" "${USERFLAGS[@]}" -c userspace/nano.cpp -o "$OUT/nano.o"
"$LD" -m elf64lriscv -T userspace/user_init.ld --build-id=none "$OUT/nano.o" -o "$OUT/nano.elf"
"$CXX" "${USERFLAGS[@]}" -c userspace/calc.cpp -o "$OUT/calc.o"
"$LD" -m elf64lriscv -T userspace/user_init.ld --build-id=none "$OUT/calc.o" -o "$OUT/calc.elf"

log 2 'Building MyFS host tool and shell filesystem image'
"$CXX" -std=c++17 -O2 -Wall -Wextra -pedantic fs/mkfs_myfs.cpp -o "$HOST_TOOLS/mkfs_myfs"
if [[ ! -f storage/disk.img ]]; then
    dd if=/dev/zero of=storage/disk.img bs=512 count=32768 2>/dev/null
fi
"$HOST_TOOLS/mkfs_myfs" storage/disk.img "$OUT/user_init.elf" "$OUT/nano.elf" "$OUT/calc.elf" >/dev/null

log 3 'Compiling RISC-V boot, traps, shell, core kernel, and drivers'
compile_asm boot boot/boot.S
compile_cpp bootinfo arch/riscv64/bootinfo.cpp
compile_asm exception_vectors boot/exceptions.S
compile_asm ctx_switch arch/riscv64/ctx_switch.S
compile_asm user_entry arch/riscv64/user_entry.S

MODULE_NAMES=(
  uart memory string fs vfs process sched_policy scheduler timer interrupt keyboard
  commands version shell history env rtc exceptions syscall user mmu virtio_mmio
  virtio_input virtio_blk storage thread fd elf virtio_net netstack page_alloc
  fault diag security smp kernel
)
declare -A SOURCE=(
  [uart]=arch/riscv64/uart.cpp [memory]=memory/memory.cpp [string]=kernel/string.cpp
  [fs]=fs/fs.cpp [vfs]=fs/vfs.cpp [process]=process/process.cpp [sched_policy]=process/sched_policy.cpp
  [scheduler]=process/scheduler.cpp [timer]=arch/riscv64/timer.cpp [interrupt]=arch/riscv64/interrupt.cpp
  [keyboard]=drivers/keyboard.cpp [commands]=kernel/commands.cpp [version]=kernel/version.cpp
  [shell]=kernel/shell.cpp [history]=kernel/history.cpp [env]=kernel/env.cpp [rtc]=arch/riscv64/rtc.cpp
  [exceptions]=arch/riscv64/exceptions.cpp [syscall]=kernel/syscall.cpp [user]=process/user.cpp
  [mmu]=arch/riscv64/mmu.cpp [virtio_mmio]=drivers/virtio_mmio.cpp [virtio_input]=drivers/virtio_input.cpp
  [virtio_blk]=drivers/virtio_blk.cpp [storage]=drivers/storage.cpp [thread]=process/thread.cpp [fd]=kernel/fd.cpp
  [elf]=process/elf.cpp [virtio_net]=drivers/virtio_net.cpp [netstack]=net/netstack.cpp
  [page_alloc]=memory/page_alloc.cpp [fault]=kernel/fault.cpp [diag]=kernel/diag.cpp
  [security]=kernel/security.cpp [smp]=kernel/smp.cpp [kernel]=kernel/kernel.cpp
)
for name in "${MODULE_NAMES[@]}"; do compile_cpp "$name" "${SOURCE[$name]}"; done

log 4 'Linking kernel ELF'
OBJECTS=("$OUT/boot.o" "$OUT/bootinfo.o" "$OUT/exception_vectors.o" "$OUT/ctx_switch.o" "$OUT/user_entry.o")
for name in "${MODULE_NAMES[@]}"; do OBJECTS+=("$OUT/$name.o"); done
"$LD" -m elf64lriscv -T boot/linker.ld -nostdlib --gc-sections --build-id=none "${OBJECTS[@]}" -o "$OUT/kernel.elf"

log 5 'Verifying kernel ELF metadata'
MACHINE="$("$READELF" -h "$OUT/kernel.elf" | sed -n 's/^[[:space:]]*Machine:[[:space:]]*//p' | head -n1)"
ENTRY="$("$READELF" -h "$OUT/kernel.elf" | sed -n 's/^[[:space:]]*Entry point address:[[:space:]]*//p' | head -n1)"
printf '  Machine : %s\n  Entry   : %s\n' "${MACHINE:-unknown}" "${ENTRY:-unknown}"
[[ "$MACHINE" == *RISC-V* ]] || { echo 'ERROR: expected RISC-V ELF' >&2; exit 1; }

log 6 'Running shell/core host regression tests'
HOSTFLAGS=(-std=c++17 -O2 -Wall -Wextra -pedantic -iquote include -DHOST_TEST)
run_test() {
    local name="$1"; shift
    [[ "$VERBOSE" -eq 1 ]] && printf '  TEST %s\n' "$name"
    "$CXX" "${HOSTFLAGS[@]}" "$@" -o "$HOST_TOOLS/$name"
    "$HOST_TOOLS/$name" >/dev/null
}
run_test fs_host_test tests/fs_host_test.cpp fs/fs.cpp kernel/string.cpp arch/riscv64/rtc.cpp
run_test net_host_test tests/net_host_test.cpp net/netstack.cpp
run_test mem_host_test tests/mem_host_test.cpp memory/page_alloc.cpp kernel/fault.cpp
run_test syscall_host_test tests/syscall_host_test.cpp kernel/syscall.cpp kernel/fd.cpp
run_test diag_host_test tests/diag_host_test.cpp kernel/diag.cpp
run_test vfs_host_test tests/vfs_host_test.cpp fs/vfs.cpp fs/fs.cpp kernel/string.cpp arch/riscv64/rtc.cpp
run_test sched_host_test tests/sched_host_test.cpp process/sched_policy.cpp
run_test env_host_test tests/env_host_test.cpp kernel/env.cpp kernel/string.cpp
run_test fd_host_test tests/fd_host_test.cpp kernel/fd.cpp fs/fs.cpp kernel/string.cpp arch/riscv64/rtc.cpp
run_test process_host_test tests/process_host_test.cpp process/process.cpp kernel/string.cpp
run_test scheduler_process_host_test tests/scheduler_process_host_test.cpp process/process.cpp process/scheduler.cpp process/sched_policy.cpp kernel/string.cpp
run_test smp_host_test tests/smp_host_test.cpp kernel/smp.cpp

printf '\n[OK] RISC-V64 shell-only kernel built successfully.\n'
printf 'Kernel : %s/%s\n' "$PWD" "$OUT/kernel.elf"
printf 'Runner : use linux/run.sh, termux/run.sh, macos/run.sh, or windows/run.ps1\n'
if [[ "$RUN_AFTER_BUILD" -eq 1 ]]; then exec bash "$SCRIPT_DIR/run.sh"; fi
