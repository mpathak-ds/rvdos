OUTPUT_ARCH( "riscv" )
ENTRY( _start )

SECTIONS
{
	. = 0x0;

	.text : {
		*(.text._start)
		*(.text.entry)
		*(.text .text.*)
	}

	.rodata : {
		*(.rodata .rodata.*)
	}

	.bss : {
		*(.bss .bss.*)
		*(COMMON)
	}

	/DISCARD/ : {
		*(.comment)
		*(.eh_frame)
	}
}
