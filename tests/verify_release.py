#!/usr/bin/env python3
"""Fail-closed static release checks for the MyKernel RISC-V64 source port."""
from pathlib import Path
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build" / "riscv64"
KERNEL = OUT / "kernel.elf"
DISK = ROOT / "storage" / "disk.img"
EM_RISCV = 243
ET_EXEC = 2
PT_LOAD = 1

REQUIRED = [
    "arch/riscv64/boot.S", "arch/riscv64/bootinfo.cpp",
    "arch/riscv64/exceptions.S", "arch/riscv64/exceptions.cpp",
    "arch/riscv64/ctx_switch.S", "arch/riscv64/user_entry.S",
    "arch/riscv64/mmu.cpp", "arch/riscv64/interrupt.cpp",
    "arch/riscv64/timer.cpp", "arch/riscv64/uart.cpp", "arch/riscv64/rtc.cpp",
    "kernel/kernel.cpp", "kernel/syscall.cpp", "kernel/shell.cpp",
    "kernel/fd.cpp", "kernel/security.cpp", "kernel/smp.cpp",
    "memory/memory.cpp", "memory/page_alloc.cpp", "process/process.cpp",
    "process/scheduler.cpp", "process/thread.cpp", "process/elf.cpp",
    "process/user.cpp", "fs/fs.cpp", "fs/vfs.cpp", "net/netstack.cpp",
    "drivers/virtio_mmio.cpp", "drivers/virtio_blk.cpp", "drivers/virtio_net.cpp",
    "drivers/virtio_input.cpp", "drivers/fb.cpp", "ui/ui.cpp", "ui/image.cpp",
    "include/user_api.h", "include/exception_frame.h", "include/mmu.h",
    "userspace/user_init.ld", "userspace/nano.cpp", "userspace/calc.cpp",
    "tests/fs_host_test.cpp", "tests/net_host_test.cpp", "tests/syscall_host_test.cpp",
    "tests/fd_host_test.cpp", "tests/process_host_test.cpp", "tests/ui_host_test.cpp",
    "tests/ui_image_host_test.cpp", "docs/BUILD_AND_RUN.md", "docs/ARCHITECTURE.md",
    "apps/terminal.rpk", "apps/calculator.rpk", "apps/clock.rpk", "apps/files.rpk",
    "apps/launcher.rpk", "apps/wallpaper.rpk", "apps/pengaturan.rpk",
    "assets/wallpapers/rioos-default.bmp", "assets/icons/terminal.bmp",
    "assets/icons/calculator.bmp", "assets/icons/clock.bmp", "assets/icons/files.bmp",
    "assets/icons/launcher.bmp", "assets/icons/wallpaper.bmp", "assets/icons/settings.bmp",
    "build.sh", "run.sh", "run-ui.sh", ".github/workflows/ci.yml",
]
for rel in REQUIRED:
    assert (ROOT / rel).is_file(), f"missing required RISC-V release file: {rel}"

for image in (KERNEL, OUT / "user_init.elf", OUT / "nano.elf", OUT / "calc.elf"):
    assert image.is_file() and image.stat().st_size > 0, f"missing/empty ELF: {image.relative_to(ROOT)}"

assert DISK.is_file() and DISK.stat().st_size == 32768 * 512, "MyFS disk must be exactly 16 MiB"


def elf_info(path: Path):
    data = path.read_bytes()
    assert data[:4] == b"\x7fELF", f"bad ELF magic: {path.name}"
    assert data[4] == 2 and data[5] == 1, f"expected ELF64 little-endian: {path.name}"
    e_type, machine = struct.unpack_from("<HH", data, 16)
    entry = struct.unpack_from("<Q", data, 24)[0]
    phoff = struct.unpack_from("<Q", data, 32)[0]
    ehsize, phentsize, phnum = struct.unpack_from("<HHH", data, 52)
    assert e_type == ET_EXEC, f"expected executable ELF: {path.name}"
    assert machine == EM_RISCV, f"expected EM_RISCV (243): {path.name}, got {machine}"
    assert ehsize == 64 and phentsize == 56 and 0 < phnum <= 32, f"bad ELF header/program headers: {path.name}"
    assert phoff <= len(data) and phnum * phentsize <= len(data) - phoff, f"program headers out of file: {path.name}"
    ranges = []
    entry_exec = False
    for i in range(phnum):
        off = phoff + i * phentsize
        p_type, p_flags = struct.unpack_from("<II", data, off)
        p_offset, p_vaddr, _paddr, p_filesz, p_memsz, p_align = struct.unpack_from("<QQQQQQ", data, off + 8)
        if p_type != PT_LOAD:
            continue
        assert p_filesz <= p_memsz, f"PT_LOAD filesz > memsz: {path.name}"
        assert p_offset <= len(data) and p_filesz <= len(data) - p_offset, f"PT_LOAD exceeds file: {path.name}"
        assert p_memsz > 0, f"empty PT_LOAD: {path.name}"
        assert p_align in (0, 1) or (p_align & (p_align - 1)) == 0, f"bad PT_LOAD alignment: {path.name}"
        end = p_vaddr + p_memsz
        assert end >= p_vaddr, f"PT_LOAD address overflow: {path.name}"
        ranges.append((p_vaddr, end, p_flags))
        if p_flags & 1 and p_vaddr <= entry < end:
            entry_exec = True
    assert ranges and entry_exec, f"entry point is not in an executable PT_LOAD: {path.name}"
    for i, (a0, a1, _af) in enumerate(ranges):
        for b0, b1, _bf in ranges[i + 1:]:
            # ELF segment byte ranges may not overlap; kernel loader additionally
            # refuses shared permission pages when it loads user applications.
            assert not (a0 < b1 and b0 < a1), f"overlapping PT_LOAD ranges: {path.name}"
    return data, machine, entry, ranges

kdata, kmachine, kentry, _kranges = elf_info(KERNEL)
assert kentry == 0x80200000, f"kernel entry changed unexpectedly: {kentry:#x}"
for app_name in ("user_init.elf", "nano.elf", "calc.elf"):
    data, machine, entry, ranges = elf_info(OUT / app_name)
    assert 0x47000000 <= entry < 0x47800000, f"userspace entry outside configured U-mode image window: {app_name}"
    for start, end, _flags in ranges:
        assert 0x47000000 <= start < 0x47800000 and end <= 0x47800000, f"userspace segment outside U-mode image window: {app_name}"

nm_tool = shutil.which("nm") or shutil.which("llvm-nm")
readelf_tool = shutil.which("readelf") or shutil.which("llvm-readelf")
assert nm_tool, "nm or llvm-nm is required for release checks"
assert readelf_tool, "readelf or llvm-readelf is required for release checks"
symbols = subprocess.check_output([nm_tool, "-C", "-n", str(KERNEL)], text=True)
for symbol in ("thread_context_switch", "thread_trampoline", "riscv64_trap_entry", "riscv64_trap_dispatch", "mmu_init", "syscall_dispatch", "fd_open(", "fd_read(", "virtio_mmio_find_device(", "fb_init(", "net_udp_socket("):
    assert any(symbol in line for line in symbols.splitlines()), f"feature symbol not linked: {symbol}"
undefined = subprocess.check_output([nm_tool, "-u", str(KERNEL)], text=True).strip()
assert not undefined, f"kernel has unresolved symbols:\n{undefined}"

user_api = (ROOT / "include" / "user_api.h").read_text()
assert 'register uint64_t a7 asm("a7")' in user_api and 'asm volatile("ecall"' in user_api, "RISC-V user syscall ABI wrappers missing"
syscall = (ROOT / "kernel" / "syscall.cpp").read_text()
assert "#define SC_ARG(frame, n) ((frame)->x[10 + (n)])" in syscall and "#define SC_NUM(frame) ((frame)->x[17])" in syscall, "RISC-V syscall register mapping missing"
elf_src = (ROOT / "process" / "elf.cpp").read_text()
assert "eh->machine != EM_RISCV" in elf_src and 'asm volatile("fence.i"' in elf_src, "RISC-V ELF loader/cache sync missing"
mmu_src = (ROOT / "arch" / "riscv64" / "mmu.cpp").read_text()
for marker in ("satp", "sfence.vma", "PTE_U", "mmu_user_pointer_ok"):
    assert marker in mmu_src, f"Sv39/MMU feature missing: {marker}"
trap_src = (ROOT / "arch" / "riscv64" / "exceptions.S").read_text()
for marker in ("csrw sepc", "csrw sstatus", "sret", "sd a7", "sd zero, 296(sp)"):
    assert marker in trap_src, f"RISC-V trap/return path missing: {marker}"
frame_src = (ROOT / "include" / "exception_frame.h").read_text()
assert "sizeof(ExceptionFrame) == 304" in frame_src, "RV64 trap frame must match 304-byte assembly frame"

print("RISC-V64 RELEASE STATIC CHECK: PASS")
