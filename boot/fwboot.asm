;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    fwboot.asm
;    14/09/26
;    mpathak
;    This module controls the startup code such as setting up the trap vectors and
;    the stack of the processor.
;--*

.section .init
.global _start

_start:
    ;copy .data from LMA to VMA
    la   a0, _data_lma
    la   a1, _data_vma_start
    la   a2, _data_vma_end
1:  bge  a1, a2, 2f
    lw   a3, 0(a0)
    sw   a3, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j    1b
2:
    ;zero .bss
    la   a1, _bss_start
    la   a2, _bss_end
3:  bge  a1, a2, 4f
    sw   zero, 0(a1)
    addi a1, a1, 4
    j    3b
4:
    ;Set up the stack top from linker
    la sp, _stack_top
    la t0, TrapHandler
    ;On machine mode MTVEC holds exception call address
    csrw mtvec, t0

	;Call the entry
	call MainStartup
hangboot: j hangboot

TrapHandler:
    ;Just write a marker now so we know while dbg
	li t0, 0x20000000
	li t1, 0xDEADBEEF
	sw t1, 0(t0)
	j TrapHandler
