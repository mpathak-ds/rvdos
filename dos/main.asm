;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    main.asm
;    14/09/26
;    mpathak
;    This module is the entry point.
;--*

.section .text
.global MainStartup
.global MainHandleTrap

.include "inc/priv/fs.inc"

.equ TEST_PAYLOAD_LEN, 24

;
; FUNCTION DESCRIPTION
;
; This is the entry point of RV DOS.
;
; FUNCTION PARAMETERS
;
; None.
;
MainStartup:
	;Initialize USART1
	call UartInitialize
	;Initialize flash
	call FpecInitialize

	;Check if TFFS is already present
	li t0, FS_MAGIC_ADDR
	lw t1, 0(t0)
	li t2, FS_MAGIC_VAL
	beq t1, t2, .skip_format_fs

	;Initialize filesystem since not present
	call FsFormatAll

	;
	;TEMPORARY FILESYSTEM TEST
	;

	;create
	la a0, _test_file_name
	li a1, 1
	call FsCreateFile

	;open
	la a0, _test_file_name
	la a1, _fs_struct
	call FsOpenFile
	beqz a0, main_loop

	;write
	la a0, _fs_struct
	la a1, _test_payload
	li a2, TEST_PAYLOAD_LEN
	call FsWriteFile

	;read
	la a0, _fs_struct
	la a1, _test_buf_read
	li a2, TEST_PAYLOAD_LEN
	call FsReadFile
	mv a0, a1
	call WriteString
	li a0, '\n'
	call WriteCharacter

.skip_format_fs:
	;Launch command
	call CmdInit

main_loop: j main_loop

;
; FUNCTION DESCRIPTION
;
; This handles ECALL dispatching and invoked only by trap
; handler.
;
;
MainHandleTrap:
	addi sp, sp, -16
	sw ra, 12(sp)
	sw s0, 8(sp)

	;saved trap frame
	mv s0, a0

	;syscall num in a0
	lw t0, 16(s0)
	;a1=arg 1
	lw t1, 20(s0)

	;ecall 0
	li t2, 0
	beq t0, t2, .ex_write_char

	;ecall 1
	li t2, 1
	beq t0, t2, .ex_read_char

.trap_exit:
	lw s0, 8(sp)
	lw ra, 12(sp)
	addi sp, sp, 16
	ret

;ECALL 0 - WriteCharacter
;a1 - arg1
.ex_write_char:
	mv a0, t1
	call WriteCharacter
	j .trap_exit

;ECALL 1 - ReadCharacterB
;a0 - return char
.ex_read_char:
	call ReadCharacterB
	;return val
	sw a0, 16(s0)
	j .trap_exit

.data
_test_file_name: .string "TEST"
_test_payload: .string "THIS IS A TEST FILE!"

.bss
.align 2
_fs_struct: .space 16
_test_buf_read: .space 24
