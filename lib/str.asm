;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    str.asm
;    14/09/26
;    mpathak
;    String library.
;--*

.section .text
.global LibStrlen

;
; FUNCTION DESCRIPTION
;
; This function measures the length of a null terminated
; string.
;
; FUNCTION PARAMETERS
;
; t4 - Address to string.
;
; FUNCTION CLOBBERS
;
; None.
;
; FUNCTION RETURN
;
; t0 - Length of string.
;
LibStrlen:
	;prologue
	addi sp, sp, -8
	sw t1, 4(sp)
	sw t4, 0(sp)

	;t0 acts as counter
	li t0, 0

lib_strlen_l1:
	lbu t1, 0(t4)
	beqz t1, lib_strlen_e1
	add t0, t0, 1
	add t4, t4, 1
	j lib_strlen_l1

lib_strlen_e1:
	;t0 now contains length, but dont clobber regs
	lw t1, 4(sp)
	lw t4, 0(sp)
	addi sp, sp, 8
	ret
