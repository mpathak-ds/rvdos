;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    eint.asm
;    16/09/26
;    mpathak
;    This module implements INT21H hook functions.
;--*

.section .text
.global EmuIntPchar
.global EmuIntExit
.global EmuIntPstring

;
;AH=2H
;
EmuIntPchar:
	;extract DL
	andi a1, s4, 0xFF
	li a0, 0
	ecall
	j .emu_fetch_byte

;
;AH=4CH
;
EmuIntExit:
	;just print newline and go
	li a0, 0
	li a1, '\n'
	ecall
	j EmuCleanExit

;
;AH=09H
;
EmuIntPstring:
	;calc phys pointer
	slli t5, s5, 4
	add t5, t5, s4
	add t5, t5, s2

	addi sp, sp, -8
	sw s6, 4(sp)
	sw ra, 0(sp)

	mv s6, t5

.pstring_loop:
	lbu a1, 0(s6)
	;DOS only terminates off dollar sign
	li t6, '$'
	beq a1, t6, .pstring_done

	li a0, 0
	;a1 already has char
	ecall

	addi s6, s6, 1
	j .pstring_loop

.pstring_done:
	lw ra, 0(sp)
	lw s6, 4(sp)
	addi sp, sp, 8
	j .emu_fetch_byte
