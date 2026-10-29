# P4 — SMP and driver hardening

## Included

- CPU identification and online-CPU/SMP status reporting. The active port remains single-hart until secondary-core startup, per-CPU stacks/state, interrupt routing, and synchronization requirements are complete.
- Acquire/release spinlock primitives with try-lock support. These are groundwork only and do not imply that current subsystems are SMP-safe.
- VirtIO-Net receive validation that rejects invalid device-reported lengths and avoids silently truncating Ethernet frames.
- Host regression tests for the SMP default-state contract and the network receive path.

## Limits

- No secondary CPU is released and SMP remains disabled.
- Timer IRQ stays disabled during normal boot.
- Host tests do not replace runtime testing of serial input, VirtIO storage, and networking under QEMU.

The active build is UART-shell-only and does not include graphical or framebuffer subsystems.
