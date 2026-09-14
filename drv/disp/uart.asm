;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    uart.asm
;    14/09/26
;    mpathak
;    This module handles driving the USART1 onboard.
;--*

.section .text
.global UartInitialize
.global UartWriteChar
.global UartWriteString

;
; FUNCTION DESCRIPTION
;
; This function enables the clock for the USART1.
;
; FUNCTION PARAMETERS
;
; None.
;
; FUNCTION CLOBBERS
;
; t0, t1, t2
;
UartInitialize:
	;First, enable the USART1 clock..
	;RCC_APB2PCENR.USART1EN
	;|= (1<<14)
	lui t0, 0x40021
	lw t1, 24(t0)
	li t2, 0x4000
	or t1, t1, t2
	sw t1, 24(t0)

	;Enable USART1 itself
	;USART1_CTLR1sex
	;=(1 << 13) | (1 << 3)

	li t0, 0x4001380C
	li t1, 0x2008
	sw t1, 0(t0)
	ret

;
; FUNCTION DESCRIPTION
;
; This function writes a single character to the output USART1.
;
; FUNCTION PARAMETERS
;
; t3 - Character to write.
;
; FUNCTION CLOBBERS
;
; None.
;
UartWriteChar:
	;prologue
	addi sp, sp, -12
	sw t0, 8(sp)
	sw t1, 4(sp)
	sw t2, 0(sp)

	;wait for TXE
	li t0, 0x40013800
	li t1, 0x80
uart_l1:
	lw t2, 0(t0)
	and t2, t2, t1
	beqz t2, uart_l1

	li t0, 0x40013804
	sw t3, 0(t0)

	;epilogue
	lw t2, 0(sp)
	lw t1, 4(sp)
	lw t0, 8(sp)
	addi sp, sp, 12
	
	ret

;
; FUNCTION DESCRIPTION
;
; This function writes a null terminated string to the output
; USART1.
;
; FUNCTION PARAMETERS
;
; t4 - String address.
;
; FUNCTION CLOBBERS
;
; None.
;
UartWriteString:
	;prologue
	addi sp, sp, -16
	sw ra, 12(sp)
	sw t4, 8(sp)
	sw t3, 4(sp)
	sw t0, 0(sp)

uart_w_l1:
	lbu t0, 0(t4)
	beqz t0, uart_w_e1

	mv t3, t0
	call UartWriteChar
	
	addi t4, t4, 1
	j uart_w_l1
uart_w_e1:
	;epilogue
	lw t0, 0(sp)
	lw t3, 4(sp)
	lw t4, 8(sp)
	lw ra, 12(sp)
	addi sp, sp, 16
	ret
