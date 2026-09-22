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

	la a0, _format_msg
	call WriteString
	call UartReadCharB

	la a0, _first_boot
	call WriteString

	;Initialize filesystem since not present
	call FsFormatAll

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

	;ecall 2
	li t2, 2
	beq t0, t2, .ex_exit_prog

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

;ECALL 2 - ExitProgram
;No arguments
.ex_exit_prog:
	la t0, .ldr_prg_done
	csrw mepc, t0
	j .trap_exit

.data
.align 4
.ifdef LANG_GER
    .include "inc/lang/ger.inc"
.else
    .ifdef LANG_FRE
        .include "inc/lang/fre.inc"
    .else
        .ifdef LANG_JPN
            .include "inc/lang/jpn.inc"
        .else
            .ifdef LANG_NED
                .include "inc/lang/ned.inc"
			.else
				.ifdef LANG_RUS
					.include "inc/lang/rus.inc"
	            .else
	                ;english US is default
	                .include "inc/lang/eng.inc"
	            .endif
			.endif
        .endif
    .endif
.endif

.global _format_msg
.global _first_boot
.global _prog_err_msg
