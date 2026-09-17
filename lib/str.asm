;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    str.asm
;    14/09/26
;    mpathak
;    String library.
;--*

.section .text
.global StrLen
.global StrCmp
.global HexToStr
.global StrToHex
.global SplitArgs

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
StrLen:
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

;
; FUNCTION DESCRIPTION
;
; This function compares two strings.
;
; FUNCTION PARAMETERS
;
; a0, a1 - Pointers to both strings.
;
; FUNCTION CLOBBERS
;
; None.
;
; FUNCTION RETURN
;
; a0 - 0 if both equal, 1 otherwise.
;
StrCmp:
.sc_loop:
	lb t0, 0(a0)
	lb t1, 0(a1)
	bne t0, t1, .sc_ne
	beqz t0, .sc_eq
	addi a0, a0, 1
	addi a1, a1, 1
	j .sc_loop
.sc_ne:
	li a0, 1
	ret
.sc_eq:
	li a0, 0
	ret

;
; FUNCTION DESCRIPTION
;
; This function converts a 32 bit hex val to the hex string
; representation of it.
;
; FUNCTION PARAMETERS
;
; a0 - Value.
; a1 - Address of destination buffer (must be at least 9 bytes).
;
; FUNCTION CLOBBERS
;
; None.
;
; FUNCTION RETURN
;
; a0 - Address of destination buffer (same as input a1).
;
HexToStr:
	;prologue
	addi sp, sp, -16
	sw t0, 12(sp)
	sw t1, 8(sp)
	sw t2, 4(sp)
	sw t3, 0(sp)

	;t3=write ptr
	mv t3, a1
	;starting shift amount
	li t2, 28

lib_hextostr_l1:
	srl t0, a0, t2
	andi t0, t0, 0xF
	li t1, 10
	blt t0, t1, lib_hextostr_digit
	addi t0, t0, ('a' - 10)
	j lib_hextostr_store
lib_hextostr_digit:
	addi t0, t0, '0'
lib_hextostr_store:
	sb t0, 0(t3)
	addi t3, t3, 1
	addi t2, t2, -4
	bgez t2, lib_hextostr_l1

	;null
	sb zero, 0(t3)

	;ret ptr to buffer
	mv a0, a1

	;epilogue
	lw t0, 12(sp)
	lw t1, 8(sp)
	lw t2, 4(sp)
	lw t3, 0(sp)
	addi sp, sp, 16
	ret

;
; FUNCTION DESCRIPTION
;
; This function converts a string to its hex val.
;
; FUNCTION PARAMETERS
;
; a0 - Address to string.
;
; FUNCTION CLOBBERS
;
; None.
;
; FUNCTION RETURN
;
; a0 - Parsed value.
;
StrToHex:
	;prologue
	addi sp, sp, -16
	sw t0, 12(sp)
	sw t1, 8(sp)
	sw t2, 4(sp)
	sw t3, 0(sp)

	;read ptr
	mv t3, a0
	;accumulator
	li t2, 0

	;check for 0x or 0X prefix
	lbu t0, 0(t3)
	li t1, '0'
	bne t0, t1, lib_strtohex_l1
	lbu t0, 1(t3)
	li t1, 'x'
	beq t0, t1, lib_strtohex_skip
	li t1, 'X'
	bne t0, t1, lib_strtohex_l1
lib_strtohex_skip:
	addi t3, t3, 2

lib_strtohex_l1:
	lbu t0, 0(t3)
	beqz t0, lib_strtohex_e1

	;try 0-9
	li t1, '0'
	blt t0, t1, lib_strtohex_e1
	li t1, '9'
	bgt t0, t1, lib_strtohex_lower
	addi t0, t0, -'0'
	j lib_strtohex_accum

lib_strtohex_lower:
	;try a-f
	li t1, 'a'
	blt t0, t1, lib_strtohex_upper
	li t1, 'f'
	bgt t0, t1, lib_strtohex_e1
	addi t0, t0, -('a' - 10)
	j lib_strtohex_accum

lib_strtohex_upper:
	;try A-F
	li t1, 'A'
	blt t0, t1, lib_strtohex_e1
	li t1, 'F'
	bgt t0, t1, lib_strtohex_e1
	addi t0, t0, -('A' - 10)

lib_strtohex_accum:
	slli t2, t2, 4
	add t2, t2, t0
	addi t3, t3, 1
	j lib_strtohex_l1

lib_strtohex_e1:
	;ret
	mv a0, t2

	;epilogue
	lw t0, 12(sp)
	lw t1, 8(sp)
	lw t2, 4(sp)
	lw t3, 0(sp)
	addi sp, sp, 16
	ret

;a0=input str
;a0=1st str
;a1=2nd str
SplitArgs:
	mv t0, a0
	mv a1, zero

.find_delim:
	lbu t1, 0(t0)
	beqz t1, .split_done

	li t2, ','
	beq t1, t2, .found_delim
	li t2, ' '
	beq t1, t2, .found_delim

	addi t0, t0, 1
	j .find_delim

.found_delim:
	sb zero, 0(t0)
	addi t0, t0, 1
.skip_whitespace:
	lbu t1, 0(t0)
	beqz t1, .split_done
	li t2, ' '
	beq t1, t2, .advance_ws
	li t2, ','
	beq t1, t2, .advance_ws

	mv a1, t0
	j .split_done
	
.advance_ws:
	addi t0, t0, 1
	j .skip_whitespace
.split_done:
	ret
