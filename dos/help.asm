;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    help.asm
;    15/09/26
;    mpathak
;    HELP command.
;--*

.section .text
.global CmdHelp

CmdHelp:
	addi sp, sp, -4
	sw ra, 0(sp)
	la a0, help_str
	call WriteString
	lw ra, 0(sp)
	addi sp, sp, 4
	ret

.data
help_str: .string "help, ver, echo, peek, poke, read\n"
