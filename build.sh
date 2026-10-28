#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

VERBOSE=0
CLEAN=0
RUN_QEMU=0
for arg in "$@"; do
    case "$arg" in
        -v|--verbose) VERBOSE=1 ;;
        --clean) CLEAN=1 ;;
        --run) RUN_QEMU=1 ;;
        -h|--help)
            cat <<'HELP'
MyKernel/RioOS RISC-V64 build
Usage: ./build.sh [--clean] [--verbose] [--run]
Builds a freestanding RV64 kernel for QEMU virt/OpenSBI, three user programs,
and the MyFS disk image. Requires clang, clang++, ld.lld and Python 3.
HELP
            exit 0 ;;
        *) echo "ERROR: unknown argument: $arg" >&2; exit 2 ;;
    esac
done

CLANG="${CLANG:-clang}"
CXX="${CXX:-clang++}"
LD="${LD:-ld.lld}"
READELF="${READELF:-readelf}"
PYTHON="${PYTHON:-python3}"
OUT=build/riscv64
HOST_TOOLS="${MYKERNEL_TOOLS_DIR:-$HOME/.mykernel-tools}"

for tool in "$CLANG" "$CXX" "$LD" "$PYTHON"; do
    command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: required tool '$tool' not found" >&2; exit 1; }
done
if [[ "$CLEAN" -eq 1 ]]; then rm -rf build; fi
mkdir -p "$OUT" storage storage/home "$HOST_TOOLS"

TARGET_FLAGS=(--target=riscv64-unknown-elf -march=rv64imac_zicsr_zifencei -mabi=lp64 -mcmodel=medany)
CXXFLAGS=("${TARGET_FLAGS[@]}" -Iinclude -std=c++17 -O1 -ffreestanding -fno-builtin -fno-stack-protector -fno-pic -fno-pie -fno-vectorize -fno-slp-vectorize -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions -fno-rtti -fno-threadsafe-statics -fno-use-cxa-atexit -fdata-sections -ffunction-sections -nostdlib -nostdinc++ -Wall -Wextra -Werror)
ASMFLAGS=("${TARGET_FLAGS[@]}" -ffreestanding -fno-pic -fno-pie -Iinclude)
USERFLAGS=("${TARGET_FLAGS[@]}" -Iinclude -std=c++17 -O1 -ffreestanding -fno-builtin -fno-stack-protector -fno-pic -fno-pie -fno-vectorize -fno-slp-vectorize -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions -fno-rtti -fno-threadsafe-statics -fno-use-cxa-atexit -ffunction-sections -fdata-sections -nostdlib -nostdinc++ -Wall -Wextra -Werror)

log() { printf '[%s] %s\n' "$1" "$2"; }
compile_cpp() {
    local name="$1" src="$2"
    [[ -f "$src" ]] || { echo "ERROR: missing source $src" >&2; exit 1; }
    [[ "$VERBOSE" -eq 1 ]] && echo "  CXX $src"
    "$CXX" "${CXXFLAGS[@]}" -c "$src" -o "$OUT/$name.o"
}
compile_asm() {
    local name="$1" src="$2"
    [[ "$VERBOSE" -eq 1 ]] && echo "  AS  $src"
    "$CLANG" "${ASMFLAGS[@]}" -c "$src" -o "$OUT/$name.o"
}

log 1 'Building RISC-V userspace (init, nano, calculator)'
compile_asm user_init arch/riscv64/user_init.S
"$LD" -m elf64lriscv -T userspace/user_init.ld --build-id=none "$OUT/user_init.o" -o "$OUT/user_init.elf"
"$CXX" "${USERFLAGS[@]}" -c userspace/nano.cpp -o "$OUT/nano.o"
"$LD" -m elf64lriscv -T userspace/user_init.ld --build-id=none "$OUT/nano.o" -o "$OUT/nano.elf"
"$CXX" "${USERFLAGS[@]}" -c userspace/calc.cpp -o "$OUT/calc.o"
"$LD" -m elf64lriscv -T userspace/user_init.ld --build-id=none "$OUT/calc.o" -o "$OUT/calc.elf"

log 2 'Building MyFS host tool and filesystem image'
"$CXX" -std=c++17 -O2 -Wall -Wextra -pedantic fs/mkfs_myfs.cpp -o "$HOST_TOOLS/mkfs_myfs"
if [[ ! -f storage/disk.img ]]; then dd if=/dev/zero of=storage/disk.img bs=512 count=32768 status=none; fi
APP_ELFS=("$OUT/user_init.elf" "$OUT/nano.elf" "$OUT/calc.elf")
APP_PACKAGES=(apps/terminal.rpk apps/calculator.rpk apps/clock.rpk apps/files.rpk apps/launcher.rpk apps/wallpaper.rpk apps/pengaturan.rpk)
for package in "${APP_PACKAGES[@]}"; do [[ -f "$package" ]] || { echo "ERROR: missing UI package $package" >&2; exit 1; }; done
LOCAL_ASSETS=(); for asset in assets/wallpapers/*.bmp assets/icons/*.bmp; do [[ -f "$asset" ]] && LOCAL_ASSETS+=("$asset"); done
"$HOST_TOOLS/mkfs_myfs" storage/disk.img "${APP_ELFS[@]}" "${APP_PACKAGES[@]}" "${LOCAL_ASSETS[@]}" >/dev/null

log 3 'Compiling architecture-specific entry, trap, timer, MMU and device code'
compile_asm boot arch/riscv64/boot.S
compile_cpp bootinfo arch/riscv64/bootinfo.cpp
compile_asm exception_vectors arch/riscv64/exceptions.S
compile_asm ctx_switch arch/riscv64/ctx_switch.S
compile_asm user_entry arch/riscv64/user_entry.S

# Compile shared logic plus explicit RISC-V implementations for architecture-sensitive modules.
declare -a MODULE_NAMES=(
  uart memory string fs vfs process sched_policy scheduler timer interrupt keyboard
  commands version shell history env rtc exceptions syscall user mmu virtio_mmio virtio_input virtio_blk storage thread fd
  fb font ui_font_data elf virtio_net netstack page_alloc fault diag security smp
  ui_boot ui_lock_screen ui_home_screen ui_apps ui_terminal ui_calculator ui_clock ui_file_manager ui_launcher ui_wallpaper ui_settings ui_image ui_core kernel
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
  [fb]=drivers/fb.cpp [font]=drivers/font.cpp [ui_font_data]=drivers/ui_font_data.cpp [elf]=process/elf.cpp
  [virtio_net]=drivers/virtio_net.cpp [netstack]=net/netstack.cpp [page_alloc]=memory/page_alloc.cpp
  [fault]=kernel/fault.cpp [diag]=kernel/diag.cpp [security]=kernel/security.cpp [smp]=kernel/smp.cpp
  [ui_boot]=ui/boot.cpp [ui_lock_screen]=ui/lock_screen.cpp [ui_home_screen]=ui/home_screen.cpp
  [ui_apps]=ui/apps.cpp [ui_terminal]=ui/terminal.cpp [ui_calculator]=ui/calculator.cpp [ui_clock]=ui/clock.cpp
  [ui_file_manager]=ui/file_manager.cpp [ui_launcher]=ui/launcher.cpp [ui_wallpaper]=ui/wallpaper.cpp
  [ui_settings]=ui/settings.cpp [ui_image]=ui/image.cpp [ui_core]=ui/ui.cpp [kernel]=kernel/kernel.cpp
)
for name in "${MODULE_NAMES[@]}"; do compile_cpp "$name" "${SOURCE[$name]}"; done

log 4 'Linking kernel ELF'
OBJECTS=("$OUT/boot.o" "$OUT/bootinfo.o" "$OUT/exception_vectors.o" "$OUT/ctx_switch.o" "$OUT/user_entry.o")
for name in "${MODULE_NAMES[@]}"; do OBJECTS+=("$OUT/$name.o"); done
"$LD" -m elf64lriscv -T arch/riscv64/linker.ld -nostdlib --gc-sections --build-id=none "${OBJECTS[@]}" -o "$OUT/kernel.elf"

log 5 'Verifying target ELF metadata'
MACHINE="$("$READELF" -h "$OUT/kernel.elf" | sed -n 's/^[[:space:]]*Machine:[[:space:]]*//p' | head -n1)"
ENTRY="$("$READELF" -h "$OUT/kernel.elf" | sed -n 's/^[[:space:]]*Entry point address:[[:space:]]*//p' | head -n1)"
printf '  Machine : %s\n  Entry   : %s\n' "${MACHINE:-unknown}" "${ENTRY:-unknown}"
[[ "$MACHINE" == *RISC-V* ]] || { echo "ERROR: expected RISC-V ELF" >&2; exit 1; }

log 6 'Running portable host regression tests'
HOSTFLAGS=(-std=c++17 -O2 -Wall -Wextra -pedantic -iquote include -DHOST_TEST)
run_test() { local name="$1"; shift; [[ "$VERBOSE" -eq 1 ]] && echo "  TEST $name"; "$CXX" "${HOSTFLAGS[@]}" "$@" -o "$HOST_TOOLS/$name"; "$HOST_TOOLS/$name" >/dev/null; }
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
run_test fb_host_test tests/fb_host_test.cpp drivers/fb.cpp drivers/font.cpp drivers/ui_font_data.cpp
run_test ui_host_test tests/ui_host_test.cpp drivers/fb.cpp drivers/font.cpp drivers/ui_font_data.cpp ui/boot.cpp ui/lock_screen.cpp ui/home_screen.cpp
run_test ui_image_host_test tests/ui_image_host_test.cpp drivers/fb.cpp drivers/font.cpp drivers/ui_font_data.cpp ui/image.cpp ui/settings.cpp kernel/string.cpp
"$PYTHON" tests/verify_release.py

printf '\n[OK] RISC-V64 kernel and user programs built successfully.\n'
printf 'Kernel : %s/%s\n' "$PWD" "$OUT/kernel.elf"
printf 'Runner : ./run.sh (UART shell), ./run-ui.sh (graphical UI)\n'
if [[ "$RUN_QEMU" -eq 1 ]]; then exec ./run.sh; fi
