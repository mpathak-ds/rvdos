;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    emain.asm
;    14/09/26
;    mpathak
;    This module is the main entry for DOEL.
;--*

.section .text
.global EmuStartup

;
; FUNCTION DESCRIPTION
;
; Starts DOEL.
;
; FUNCTION PARAMETERS
;
; None.
;
EmuStartup:
	;
	;We do pinned register mapping for fast exec, and so AX in 8086
	;is pinned in a single register s0. We do masking to find AL and
	;AH. Similarly s2 stores guest instruction pointer.
	;

	la s2, d_test_code

	;
	;We use t0 as how many bytes to fetch.
	;t1 for matching opcode.
	;t2 for opcode itself.
	;

	li t0, 2
	li t1, 0

	;clear regs
	li s0, 0

.emu_fetch_byte:
	;MOV AL, imm8
	li t1, 0xB0
	lbu t2, 0(s2)
	beq t2, t1, .emu_handle_movalimm8

	;advance addr and decrement bytes fetch
	addi s2, s2, 1
	addi t0, t0, -1
	bnez t0, .emu_fetch_byte

.emu_exit:
	;hang for gdb
	j .emu_exit

.emu_handle_movalimm8:
	;MOV AL, imm8

	;advance by 1 to see imm8
	lbu t3, 1(s2)
	;t3 now has imm8 so clear AL
	andi t4, s0, -256
	;set AL
	or s0, t4, t3
	;consume
	addi s2, s2, 2
	;done
	j .emu_fetch_byte

.data
.align 4
;x86 instructions test
d_test_code:
	;MOV AL, 42H
	.byte 0xB0, 0x42
