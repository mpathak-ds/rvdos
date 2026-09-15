;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    api.asm
;    15/09/26
;    mpathak
;    This exposes stable native and shim APIs.
;--*

.section .text
.global WriteCharacter
.global WriteString
.global ReadCharacterB

;
; FUNCTION DESCRIPTION
;
; This function writes a single character to the available
; display.
;
; FUNCTION PARAMETERS
;
; a0 - Character to write.
;
; FUNCTION CLOBBERS
;
; None.
;
WriteCharacter:
	addi sp, sp, -8
	sw t3, 0(sp)
	sw ra, 4(sp)
	
	mv t3, a0
	call UartWriteChar

	lw t3, 0(sp)
	lw ra, 4(sp)
	addi sp, sp, 8
	
	ret

;
; FUNCTION DESCRIPTION
;
; This function writes a string to the available display.
;
; FUNCTION PARAMETERS
;
; a0 - String address.
;
; FUNCTION CLOBBERS
;
; None.
;
WriteString:
	addi sp, sp, -8
	sw t4, 0(sp)
	sw ra, 4(sp)
	
	mv t4, a0
	call UartWriteString

	lw t4, 0(sp)
	lw ra, 4(sp)
	addi sp, sp, 8
	
	ret

;
; FUNCTION DESCRIPTION
;
; This function reads a character via polling.
;
; FUNCTION PARAMETERS
;
; None.
;
; FUNCTION RETURN
;
; a0 - Character read.
;
; FUNCTION CLOBBERS
;
; None.
;
ReadCharacterB:
	addi sp, sp, -8
	sw t0, 0(sp)
	sw ra, 4(sp)
	
	call UartReadCharB
	mv a0, t0

	lw t0, 0(sp)
	lw ra, 4(sp)
	addi sp, sp, 8
	
	ret
