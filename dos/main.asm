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

	;ecall 1
	li t0, 1
	beq a0, t0, .ex_write_char

	lw ra, 12(sp)
	addi sp, sp, 16
	ret

;ECALL 1 - WriteCharacter
;a1 - arg1
.ex_write_char:
	mv a0, a1
	call WriteCharacter

	lw ra, 12(sp)
	addi sp, sp, 16
	ret
