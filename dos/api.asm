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
.global ReadLine

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

;
; FUNCTION DESCRIPTION
;
; This function reads a line via polling and echoes
; characters as it goes.
;
; FUNCTION PARAMETERS
;
; a0 - Buffer pointer.
; a1 - Max amount of characters.
;
; FUNCTION RETURN
;
; None.
;
; FUNCTION CLOBBERS
;
; None.
;
ReadLine:
	addi sp, sp, -32
	sw ra, 28(sp)
	sw s0, 24(sp)
	sw s1, 20(sp)
	sw s2, 16(sp)

	;
	;We use s0 as current write cursor, s1 as base of buffer and
	;s2 as max length
	;

	mv s0, a0
	mv s1, a0
	mv s2, a1
	
.rl_loop:
	call ReadCharacterB

	;a0 now has char, check for NL
	li t0, '\r'
	beq a0, t0, .rl_done
	li t0, '\n'
	beq a0, t0, .rl_done

	;DEL
	li t0, 0x7f
	beq a0, t0, .rl_bspace
	;BS
	li t0, 0x08
	beq a0, t0, .rl_bspace

	sub t1, s0, s1
	addi t1, t1, 1
	;buffer full so swallow character
	bge t1, s2, .rl_loop

	sb a0, 0(s0)
	addi s0, s0, 1
	call WriteCharacter
	j .rl_loop

.rl_bspace:
	;nothing to delete
	beq s0, s1, .rl_loop
	addi s0, s0, -1
	li a0, 0x08
	call WriteCharacter
	li a0, ' '
	call WriteCharacter
	li a0, 0x08
	call WriteCharacter
	j .rl_loop

.rl_done:
	;null term
	sb zero, 0(s0)
	li a0, '\n'
	call WriteCharacter

	lw ra, 28(sp)
	lw s0, 24(sp)
    lw s1, 20(sp)
    lw s2, 16(sp)
    addi sp, sp, 32
	
	ret
