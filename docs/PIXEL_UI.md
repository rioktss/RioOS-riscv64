# RioOS Pixel UI

The RV64 port contains an optional pixel-rendered UI for QEMU `virt`, using the
`ramfb` device and QEMU `fw_cfg`. Rendering is freestanding C++ with pixel
primitives and a compact antialiased proportional font table; it does not use
SDL, Qt, LVGL, or another GUI library inside the kernel. The serial console
keeps its legacy fixed-cell font.

## Build and launch

```sh
./build.sh --clean
./run-ui.sh
```

The runner defaults to GTK. Use `RIOOS_DISPLAY=sdl ./run-ui.sh` when SDL is
available. It requests a 1024×768 XRGB8888 ram framebuffer. When `ramfb` or the
expected fw_cfg interface is absent, the kernel should report that over UART
and continue in the serial shell instead of requiring a display.

## Screens and applications

- Boot splash and lock screen
- Home screen, status area, app icons and dock
- Control Centre, theme settings, Wallpaper and Launcher
- Built-in Terminal, Calculator, Clock, Files, Wallpaper and Settings

Wallpaper and icon assets are stored locally in MyFS and referenced by `.rpk`
metadata manifests. These manifests select statically built-in UI handlers;
they are not arbitrary dynamically loaded third-party executables.

## Input

The graphical runner attaches VirtIO keyboard and absolute-position tablet
devices. Focus the QEMU window to use keyboard and pointer controls. Serial
input remains available as a fallback. The terminal app uses the same
`execute_command()` dispatcher as the serial shell, so command implementation
is shared instead of duplicated in a separate mini-shell.

## Assets

Wallpaper and app icons use uncompressed 24-bit or 32-bit BMP, up to 1 MiB per
file. Add wallpaper files to `assets/wallpapers/` or replace icon files under
`assets/icons/`, then rebuild the filesystem image. The decoder validates
format, dimensions, size and offsets, and rejects compressed or truncated BMPs.

The Inter-derived glyph table and notices are documented in
`THIRD_PARTY_NOTICES.md`. It is not Xiaomi's proprietary MiSans font or Google's
system Roboto package.

## Validation status and limitations

Host framebuffer, UI composition and image/settings tests run during
`./build.sh`. They do not verify QEMU's real graphics, pointer or keyboard
forwarding. End-to-end UI acceptance is a separate step on a host whose QEMU
build includes `ramfb`, fw_cfg DMA and the VirtIO keyboard/tablet models. Timer
interrupts remain disabled by default; the UI is polled.
