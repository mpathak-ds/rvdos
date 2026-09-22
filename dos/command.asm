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
;Defines
;

.equ MAX_LINE_LENGTH, 64

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
	la a0, line_buf
	li a1, MAX_LINE_LENGTH
	call ReadLine

	la a0, line_buf
	call CmdParse

	la a0, prompt
	call WriteString
	j cmd_repl_l1

cmd_loop: j cmd_loop

CheckComExtension:
	mv t0, a0

.glen_loop:
	lb t1, 0(t0)
	beqz t1, .glen_done
	addi t0, t0, 1
	j .glen_loop

.glen_done:
	sub t1, t0, a0
	li t2, 4
	blt t1, t2, .ext_no_match

	addi t0, t0, -4

	lb t1, 0(t0)
	li t2, '.'
	bne t1, t2, .ext_no_match

	lb t1, 1(t0)
	li t2, 'c'
	li t3, 'C'
	beq t1, t2, .chk_o
	bne t1, t3, .ext_no_match

.chk_o:
	lb t1, 2(t0)
	li t2, 'o'
	li t3, 'O'
	beq t1, t2, .chk_m
	bne t1, t3, .ext_no_match

.chk_m:
	lb t1, 3(t0)
	li t2, 'm'
	li t3, 'M'
	beq t1, t2, .ext_match
	bne t1, t3, .ext_no_match

.ext_match:
	li a0, 1
	ret

.ext_no_match:
	li a0, 0
	ret

CmdParse:
	addi sp, sp, -32
	sw ra, 28(sp)
	sw s0, 24(sp)
	sw s1, 20(sp)
	sw s2, 16(sp)

	;
	;s0 = scanning cursor, s1 = start of cmd tok,
	;s2 = ptr to args string
	;

	mv s0, a0

.pd_skip_leading:
	lb t0, 0(s0)
	beqz t0, .pd_empty
	li t1, ' '
	bne t0, t1, .pd_tok_start
	addi s0, s0, 1
	j .pd_skip_leading

.pd_tok_start:
	mv s1, s0

.pd_scan_tok:
	lb t0, 0(s0)
	beqz t0, .pd_end_tok
	li t1, ' '
	beq t0, t1, .pd_end_tok
	addi s0, s0, 1
	j .pd_scan_tok

.pd_end_tok:
	lb t0, 0(s0)
	beqz t0, .pd_args_ptr_set
	sb zero, 0(s0)
	addi s0, s0, 1

.pd_skip_mid:
	lb t0, 0(s0)
	beqz t0, .pd_args_ptr_set
	li t1, ' '
	bne t0, t1, .pd_args_ptr_set
	addi s0, s0, 1
	j .pd_skip_mid

.pd_args_ptr_set:
	mv s2, s0
	la t2, cmd_table
.pd_table_loop:
	;name pointer
	lw t3, 0(t2)
	beqz t3, .pd_not_found
	;handler pointer
	lw t4, 4(t2)

	mv a0, s1
	mv a1, t3
	call StrCmp
	beqz a0, .pd_match

	addi t2, t2, 8
	j .pd_table_loop

.pd_match:
	;trimmed arguments to handler
	mv a0, s2
	jalr t4
	j .pd_ret

.pd_not_found:
	mv a0, s1

	;check if COM
	call CheckComExtension
	bnez a0, .pd_launch_emu

	;not com
	mv a0, s1
	mv a1, s2
	call LdrLoadProg
	j .pd_ret

.pd_launch_emu:
	mv a0, s1
	mv a1, s2
	call EmuStartup
	j .pd_ret

.pd_empty:
.pd_ret:
	lw ra, 28(sp)
	lw s0, 24(sp)
	lw s1, 20(sp)
	lw s2, 16(sp)
	addi sp, sp, 32
	ret

;
;Variables
;

.data
welcome_banner:
	.string "RV-DOS Version 1.00\n> "
new_line:
	.string "\n"
prompt: .string "> "

cmd_table:
	.word cmd_name_ver, CmdVer
	.word cmd_name_help, CmdHelp
	.word cmd_name_echo, CmdEcho
	.word cmd_name_peek, CmdPeek
	.word cmd_name_poke, CmdPoke
	.word cmd_name_read, CmdRead
	.word cmd_name_load, LdrLoadDrv
	.word cmd_name_dir, FsListFiles
	.word 0 ;end of table

cmd_name_ver: .string "ver"
cmd_name_help: .string "help"
cmd_name_echo: .string "echo"
cmd_name_peek: .string "peek"
cmd_name_poke: .string "poke"
cmd_name_read: .string "read"
cmd_name_load: .string "start"
cmd_name_dir: .string "dir"

.bss
.align 4
line_buf: .space MAX_LINE_LENGTH + 1 ;null terminator
