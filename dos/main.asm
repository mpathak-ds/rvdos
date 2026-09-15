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
