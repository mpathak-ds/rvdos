;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    emain.asm
;    14/09/26
;    mpathak
;    This module is the main entry for DOEL86.
;--*

.section .text
.global EmuStartup
.global .emu_fetch_byte
.global EmuCleanExit

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
	;AH. Similarly s2 stores guest base mem addr. s3 stores CS and
	;s1 stores IP.
	;
	;Full register context:
	;
	;s0=AX
	;s1=IP
	;s2=GUEST BASE
	;s3=CS
	;s4=DX
	;s5=DS
	;

	la t0, _d_saved_ra
	sw ra, 0(t0)

	;CS
	li s3, 0
	;open file
	la a1, _d_fs_struct
	;a0 has filename we want already
	call FsOpenFile
	beqz a0, .emu_fail_err

	la s2, _d_guest_mem

	la a0, _d_fs_struct
	addi a1, s2, 0x100
	li a2, 4096
	call FsReadFile

	;PSP
	li t0, 0xCD
	sb t0, 0(s2)
	li t0, 0x20
	sb t0, 1(s2)

	li t0, 0xFF
	sb t0, 2(s2)
	li t0, 0x9F
	sb t0, 3(s2)

	li t0, 0xCD
	sb t0, 10(s2)
	li t0, 0x20
	sb t0, 11(s2)

	sb zero, 0x80(s2)
	li t0, 0x0D
	sb t0, 0x81(s2)

	;0x100 ORG
	li s1, 0x100
	;DS
	li s5, 0
	;AX
	li s0, 0
	;DX
	li s4, 0

	;
	;t1 for matching opcode.
	;t2 for opcode itself.
	;

	li t1, 0

.emu_fetch_byte:
	;phys = s2+(s3<<4)+s1
	slli t5, s3, 4
	add t5, t5, s1
	add t5, t5, s2
	lbu t2, 0(t5)
	addi s1, s1, 1

	;MOV AL, imm8
	li t1, 0xB0
	beq t2, t1, .emu_handle_movalimm8

	;MOV AH, imm8
	li t1, 0xB4
	beq t2, t1, .emu_handle_movahimm8

	;MOV DL, imm8
	li t1, 0xB2
	beq t2, t1, .emu_handle_movdlimm8

	;MOV DH, imm8
	li t1, 0xB6
	beq t2, t1, .emu_handle_movdhimm8

	;MOV DX, imm16
	li t1, 0xBA
	beq t2, t1, .emu_handle_movdximm16

	;MOV AX, imm16
	li t1, 0xB8
	beq t2, t1, .emu_handle_movaximm16

	;MOV R16, R/M16
	li t1, 0x8B
	beq t2, t1, .emu_handle_movr16

	;INT imm8
	li t1, 0xCD
	beq t2, t1, .emu_handle_int

	;unknown
	;save to a3 incase temp gets clobbered
	mv a3, t2

.emu_unimpl_op:
	la a0, d_fail_op_msg
	call WriteString

	;convert to str
	;format: Unknown OPCODE: [code] at IP:[address]
	mv a0, a3
	la a1, d_hex_buf
	call HexToStr
	mv a0, a1
	call WriteString
	la a0, d_fail_op_msg2
	call WriteString
	mv a0, s1
	la a1, d_hex_buf
	call HexToStr
	call WriteString

	li a0, '\n'
	call WriteCharacter

EmuCleanExit:
	la t0, _d_saved_ra
	lw ra, 0(t0)
	ret

.emu_handle_movalimm8:
	;MOV AL, imm8

	;fetch at CS:IP
	slli t5, s3, 4
	add t5, t5, s1
	add t5, t5, s2
	lbu t3, 0(t5)
	addi s1, s1, 1

	;t3 now has imm8 so clear AL
	andi t4, s0, -256
	;set AL
	or s0, t4, t3
	;done
	j .emu_fetch_byte

.emu_handle_movahimm8:
	;MOV AH, imm8

	;fetch at CS:IP
	slli t5, s3, 4
	add t5, t5, s1
	add t5, t5, s2
	lbu t3, 0(t5)
	addi s1, s1, 1

	;clear AH
	li t4, 0xFFFF00FF
	and s0, s0, t4
	;shift imm8
	slli t3, t3, 8
	;set
	or s0, s0, t3
	;done
	j .emu_fetch_byte

.emu_handle_movdlimm8:
	;MOV DL, imm8

	;fetch at CS:IP
	slli t5, s3, 4
	add t5, t5, s1
	add t5, t5, s2
	lbu t3, 0(t5)
	addi s1, s1, 1

	;t3 now has imm8 so clear DL
	andi t4, s4, -256
	;set DL
	or s4, t4, t3
	
	;done
	j .emu_fetch_byte

.emu_handle_movdhimm8:
	;MOV DH, imm8

	;fetch at CS:IP
	slli t5, s3, 4
	add t5, t5, s1
	add t5, t5, s2
	lbu t3, 0(t5)
	addi s1, s1, 1

	;clear DH
	li t4, 0xFFFF00FF
	and s4, s4, t4
	;shift imm8
	slli t3, t3, 8
	;set
	or s4, s4, t3
	;done
	j .emu_fetch_byte

.emu_handle_movdximm16:
	;MOV DX, imm16

	;low byte
	slli t5, s3, 4
	add t5, t5, s1
	add t5, t5, s2
	lbu t3, 0(t5)
	addi s1, s1, 1

	;hi byte
	slli t5, s3, 4
	add t5, t5, s1
	add t5, t5, s2
	lbu t4, 0(t5)
	addi s1, s1, 1

	;combine
	slli t4, t4, 8
	or s4, t3, t4

	;done
	j .emu_fetch_byte

.emu_handle_movaximm16:
	;MOV AX, imm16

	;low byte
	slli t5, s3, 4
	add t5, t5, s1
	add t5, t5, s2
	lbu t3, 0(t5)
	addi s1, s1, 1

	;hi byte
	slli t5, s3, 4
	add t5, t5, s1
	add t5, t5, s2
	lbu t4, 0(t5)
	addi s1, s1, 1

	;combine
	slli t4, t4, 8
	or s0, t3, t4
	
	;done
	j .emu_fetch_byte

.emu_handle_movr16:
	;MOV R16, R/M16

	;TODO

	;done
	j .emu_fetch_byte

.emu_handle_int:
	;INT imm8

	;fetch at CS:IP
	slli t5, s3, 4
	add t5, t5, s1
	add t5, t5, s2
	lbu t3, 0(t5)
	addi s1, s1, 1

	;t3 now has int number
	;crude check for 21h..
	li t4, 0x21
	beq t3, t4, .emu_int21h_hook
	
	j .emu_fetch_byte

.emu_int21h_hook:
	;INT 21H

	;extract function number
	li t4, 0x00
	srli t4, s0, 8
	andi t4, t4, 0xFF

	;t4 now has function num from AH..
	;check for EXIT first
	li t5, 0x4C
	beq t4, t5, EmuIntExit
	;print char
	li t5, 0x02
	beq t4, t5, EmuIntPchar
	;print string ($)
	li t5, 0x09
	beq t4, t5, EmuIntPstring

	;unknown
	;just write a char for now ..
	li a0, 0
	li a1, '!'
	ecall
	
	j .emu_fetch_byte

.emu_fail_err:
	la a0, d_fail_err_msg
	call WriteString
	li a0, '\n'
	call WriteCharacter
	j EmuCleanExit

.data
.align 4
;x86 instructions test
d_test_code:
	;MOV DX, 0BH
	.byte 0xBA, 0x0B, 0x00
	;MOV AH, 09H
	.byte 0xB4, 0x09
	;INT 21H
	.byte 0xCD, 0x21
	;MOV AH, 4CH
	.byte 0xB4, 0x4C
	;INT 21H
	.byte 0xCD, 0x21

d_string:
	.ascii "Hello World!$"

d_test_file: .string "DOEL86.COM"
d_fail_err_msg: .string "Program not found."
d_fail_op_msg: .string "\nUnimplemented OPCODE: "
d_fail_op_msg2: .string " at IP:"
d_hex_buf: .string "0x0000000"

.bss
.align 4
_d_fs_struct: .space 16
_d_saved_ra:  .space 4
_d_guest_mem: .space 19456 ;4352
