;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    read.asm
;    19/09/26
;    mpathak
;    READ command.
;--*

.section .text
.global CmdRead

.equ CMD_READ_MAX_LEN, 128

CmdRead:
	addi sp, sp, -4
	sw ra, 0(sp)
	;args in a0 as string now

	;a0 SHOULD ideally have the filename already
	la a1, _read_fs_struct
	call FsOpenFile
	;non existent
	beqz a0, .read_fail_exit

	;read
	la a0, _read_fs_struct
	la a1, _read_buf_read
	li a2, CMD_READ_MAX_LEN
	call FsReadFile
	mv a0, a1
	call WriteString

.read_done:
	;done
	li a0, '\n'
	call WriteCharacter
	lw ra, 0(sp)
	addi sp, sp, 4
	ret
.read_fail_exit:
	la a0, _read_error_msg
	call WriteString
	j .read_done
	
.data
_hex_prefix: .string "0x"
_hex_buffer: .string "0x0000000"
_read_error_msg: .string "File does not exist."

.bss
.align 2
_read_fs_struct: .space 16
_read_buf_read: .space CMD_READ_MAX_LEN
