;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    ldr.asm
;    20/09/26
;    mpathak
;    This module handles loading drivers and programs.
;--*

.section .text
.global LdrLoadDrv
.global LdrLoadProg
.global .ldr_prg_done

.equ LDR_PROG_SRAM_ADDR, 0x20007000
.equ LDR_PROG_MAX_LEN, 4096

LdrLoadDrv:
	addi sp, sp, -4
	sw ra, 0(sp)
	;save filename
	mv a3, a0

	;a0 has filename
	la a1, _ldr_fs_struct
	;open
	call FsOpenFile
	beqz a0, .ldr_drv_err

	la a0, _ldr_fs_struct
	la a1, _ldr_drv_cont
	li a2, 512
	;read
	call FsReadFile

	;display msg
	la a0, _ldr_ldrv_msg
	call WriteString
	;retrieve filename
	mv a0, a3
	call WriteString

	;done
	j .ldr_drv_done

.ldr_drv_err:
	la a0, _prog_err_msg
	call WriteString

.ldr_drv_done:
	li a0, '\n'
	call WriteCharacter
	lw ra, 0(sp)
	addi sp, sp, 4
	ret

LdrLoadProg:
	addi sp, sp, -4
	sw ra, 0(sp)

	la t0, _ldr_ksp_save
	sw sp, 0(t0)
	
	;a0 has filename
	la a1, _ldr_fs_struct
	;open
	call FsOpenFile
	beqz a0, .ldr_prg_err

	la a0, _ldr_fs_struct
	la a1, LDR_PROG_SRAM_ADDR
	li a2, LDR_PROG_MAX_LEN
	;read
	call FsReadFile

	;jump
	li t0, LDR_PROG_SRAM_ADDR
	jalr x0, t0, 0

	;done
	j .ldr_prg_done

.ldr_prg_err:
	la a0, _prog_err_msg
	call WriteString

.ldr_prg_done:
	li a0, '\n'
	call WriteCharacter
	la t0, _ldr_ksp_save
	lw sp, 0(t0)
	lw ra, 0(sp)
	addi sp, sp, 4
	ret

.data
.align 4
_ldr_ldrv_msg: .string "Loading "

.bss
.align 4
_ldr_fs_struct: .space 16
_ldr_drv_cont: .space LDR_PROG_MAX_LEN
_ldr_ksp_save: .space 4
