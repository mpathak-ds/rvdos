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
    andi t0, t0, -4
    ;On machine mode MTVEC holds exception call address
    csrw mtvec, t0

	;Call the entry
	call MainStartup
hangboot: j hangboot

.align 4
TrapHandler:
	addi sp, sp, -64
	sw ra,  0(sp)
	sw t0,  4(sp)
	sw t1,  8(sp)
	sw t2, 12(sp)
	sw a0, 16(sp)
	sw a1, 20(sp)
	sw a2, 24(sp)
	sw a3, 28(sp)
	sw a4, 32(sp)
	sw a5, 36(sp)
	sw a6, 40(sp)
	sw a7, 44(sp)
	sw t3, 48(sp)
	sw t4, 52(sp)
	sw t5, 56(sp)
	sw t6, 60(sp)

	csrr t0, mcause
	;ecall
	li t1, 0xb
	bne t0, t1, .skip_ecall

	mv a0, sp
	call MainHandleTrap

	;advance by 4 if ecall

	lw t0, 16(sp)
	li t1, 2
	beq t0, t1, .skip_ecall
	
	csrr t2, mepc
	addi t2, t2, 4
	csrw mepc, t2

.skip_ecall:
	;not ecall, just return
	lw ra,  0(sp)
	lw t0,  4(sp)
	lw t1,  8(sp)
	lw t2, 12(sp)
	lw a0, 16(sp)
	lw a1, 20(sp)
	lw a2, 24(sp)
	lw a3, 28(sp)
	lw a4, 32(sp)
	lw a5, 36(sp)
	lw a6, 40(sp)
	lw a7, 44(sp)
	lw t3, 48(sp)
	lw t4, 52(sp)
	lw t5, 56(sp)
	lw t6, 60(sp)
	addi sp, sp, 64

	mret
