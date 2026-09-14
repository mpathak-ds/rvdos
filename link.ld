MEMORY {
  FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 256K
  SRAM  (rwx): ORIGIN = 0x20000000, LENGTH = 64K
}

SECTIONS {
  .text : { 
    *(.init) 
    *(.text*) 
  } > FLASH
  ASSERT(SIZEOF(.text) <= 32K, "ERROR: .text exceeds 32 KiB")

  .data : {
    . = ALIGN(4);
    _data_vma_start = .;
    *(.data*)
    . = ALIGN(4);
    _data_vma_end = .;
  } > SRAM AT> FLASH

  _data_lma = LOADADDR(.data);

  .bss : {
    . = ALIGN(4);
    _bss_start = .;
    *(.bss*)
    *(COMMON)
    . = ALIGN(4);
    _bss_end = .;
  } > SRAM

  _stack_top = ORIGIN(SRAM) + LENGTH(SRAM);
}
