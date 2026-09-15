;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    command.asm
;    15/09/26
;    mpathak
;    This module handles command parsing and offloading.
;--*

.section .text
.global CmdInit

;
; FUNCTION DESCRIPTION
;
; This is the entry point of COMMAND.
;
; FUNCTION PARAMETERS
;
; None.
;
CmdInit:
	;Print boot banner.
	la a0, welcome_banner
	call WriteString

cmd_repl_l1:
	;simple echo back
	call ReadCharacterB

	;make ENTER actually make a new line with >
	li t0, '\r'
	bne a0, t0, 1f
	la a0, new_line
	call WriteString
	li a0, ' '
1:
	call WriteCharacter
	j cmd_repl_l1

cmd_loop: j cmd_loop

.data
welcome_banner:
    .string "RV-DOS Version 1.00\n> "
new_line:
	.string "\n>"
