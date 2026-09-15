;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    ver.asm
;    15/09/26
;    mpathak
;    VER command.
;--*

.section .text
.global CmdVer

CmdVer:
	addi sp, sp, -4
	sw ra, 0(sp)
	la a0, ver_string
	call WriteString
	lw ra, 0(sp)
	addi sp, sp, 4
	ret

.data
ver_string: .string "RV-DOS 1.00\n"
