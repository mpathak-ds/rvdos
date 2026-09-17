;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    memac.asm
;    17/09/26
;    mpathak
;    This module handles memory access commands such as PEEK, POKE.
;--*

.section .text
.global CmdPeek
.global CmdPoke

CmdPeek:
	addi sp, sp, -4
	sw ra, 0(sp)
	;args in a0 as string now
	
	;
	;First we need to convert that to a real, 32 bit
	;value
	;

	call StrToHex

	;load the actual val at that addr
	lw t0, 0(a0)
	mv a0, t0
	;convert to string hex
	la a1, _hex_buffer
	call HexToStr
	mv t1, a0
	;write 0x prefix
	la a0, _hex_prefix
	call WriteString
	;now write the actual val retrieved
	mv a0, t1
	call WriteString

	;done
	li a0, '\n'
	call WriteCharacter
	
	lw ra, 0(sp)
	addi sp, sp, 4
	ret

CmdPoke:
	addi sp, sp, -16
	sw ra, 12(sp)
	sw s0, 8(sp)
	sw s1, 4(sp)
	
	;args in a0 as string now

	call SplitArgs
	;second arg doesnt exist
	beqz a1, .poke_error
	mv s0, a1

	call StrToHex
	mv s1, a0
	
	mv a0, s0
	call StrToHex

	sw a0, 0(s1)

.poke_error:
	lw s1, 4(sp)
	lw s0, 8(sp)
	lw ra, 12(sp)
	addi sp, sp, 16
	ret

.data
_hex_prefix: .string "0x"
_hex_buffer: .string "0x0000000"
