;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    echo.asm
;    15/09/26
;    mpathak
;    ECHO command.
;--*

.section .text
.global CmdEcho

CmdEcho:
	addi sp, sp, -4
	sw ra, 0(sp)
	;args already in a0
	call WriteString
	li a0, '\n'
	call WriteCharacter
	lw ra, 0(sp)
	addi sp, sp, 4
	ret
