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
	ret
