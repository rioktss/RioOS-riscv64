OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
    /* QEMU virt RAM starts at 0x80000000; OpenSBI loads the S-mode payload at
       0x80200000. Keep the kernel identity-mapped after enabling Sv39. */
    . = 0x80200000;
    __kernel_start = .;

    .text : ALIGN(4096)
    {
        __kernel_exec_start = .;
        KEEP(*(.text.boot))
        KEEP(*(.text.vectors))
        *(.text .text.*)
        . = ALIGN(4096);
        __kernel_exec_end = .;
    }

    .rodata : ALIGN(4096)
    {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    }

    .data : ALIGN(4096)
    {
        *(.data .data.*)
        *(.sdata .sdata.*)
    }

    .bss (NOLOAD) : ALIGN(4096)
    {
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4096);
        __bss_end = .;
    }

    .stack (NOLOAD) : ALIGN(4096)
    {
        KEEP(*(.stack .stack.*))
        . = ALIGN(4096);
    }

    . = ALIGN(4096);
    __kernel_end = .;
    __heap_start = .;

    /DISCARD/ :
    {
        *(.comment)
        *(.eh_frame .eh_frame.*)
        *(.note .note.*)
    }
}
