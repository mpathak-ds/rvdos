;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    fpec.asm
;    16/09/26
;    abell
;    This module handles driving the FPEC onboard.
;--*

.section .text
.global FpecUnlock
.global FpecLock
.global FpecErasePage
.global FpecWrite
.global FpecInitialize

.equ FPEC_BASE,     0x40022000
.equ FPEC_KEYR,     0x40022004
.equ FPEC_STATR,    0x4002200C
.equ FPEC_CTLR,     0x40022010
.equ FPEC_ADDR,     0x40022014

.equ FPEC_STATR_BSY,   0x01
.equ FPEC_STATR_WRPRT, 0x10
.equ FPEC_STATR_EOP,   0x20

.equ FPEC_CTLR_PG,     0x01
.equ FPEC_CTLR_PER,    0x02
.equ FPEC_CTLR_STRT,   0x40
.equ FPEC_CTLR_LOCK,   0x80

.equ MARKER_TEST_ADDR, 0x08010000

FpecWaitBusy:
	li t0, FPEC_STATR
.L_wait_busy:
	lw t1, 0(t0)
	andi t1, t1, FPEC_STATR_BSY
	bnez t1, .L_wait_busy
	ret

FpecUnlock:
	li t0, FPEC_CTLR
	lw t1, 0(t0)
	andi t1, t1, FPEC_CTLR_LOCK
	beqz t1, .L_unlock_done

	li t0, FPEC_KEYR
	li t1, 0x45670123
	sw t1, 0(t0)
	li t1, 0xCDEF89AB
	sw t1, 0(t0)
.L_unlock_done:
	ret

FpecLock:
	li t0, FPEC_CTLR
	lw t1, 0(t0)
	ori t1, t1, FPEC_CTLR_LOCK
	sw t1, 0(t0)
	ret

FpecErasePage:
	addi sp, sp, -16
	sw ra, 12(sp)
	sw s0, 8(sp)
	mv s0, a0

	jal FpecWaitBusy

	li t0, FPEC_CTLR
	lw t1, 0(t0)
	ori t1, t1, FPEC_CTLR_PER
	sw t1, 0(t0)

	li t0, FPEC_ADDR
	sw s0, 0(t0)

	li t0, FPEC_CTLR
	lw t1, 0(t0)
	ori t1, t1, FPEC_CTLR_STRT
	sw t1, 0(t0)

	jal FpecWaitBusy

	li t0, FPEC_STATR
	lw t1, 0(t0)
	andi t2, t1, FPEC_STATR_EOP
	beqz t2, .L_erase_chk_err
	li t2, FPEC_STATR_EOP
	sw t2, 0(t0)

.L_erase_chk_err:
	li t0, FPEC_CTLR
	lw t1, 0(t0)
	andi t1, t1, ~FPEC_CTLR_PER
	sw t1, 0(t0)

	li t0, FPEC_STATR
	lw t1, 0(t0)
	andi t1, t1, FPEC_STATR_WRPRT
	beqz t1, .L_erase_ok
	li a0, -1
	j .L_erase_exit

.L_erase_ok:
	li a0, 0

.L_erase_exit:
	lw s0, 8(sp)
	lw ra, 12(sp)
	addi sp, sp, 16
	ret
	
;
; FUNCTION DESCRIPTION
;
; This function writes data to flash in 16 bit half word
; chunks.
;
; FUNCTION PARAMETERS
;
; a0 - Target address (16 bit aligned).
; a1 - Source data pointer.
; a2 - Length ( bytes).
;
; FUNCTION CLOBBERS
;
; t0, t1, t2, t3
;
; FUNCTION RETURN
;
; a0 - 0 on success, -1 on invalid param and -2 on write err.
;
FpecWrite:
	andi t0, a0, 1
	bnez t0, .L_write_err_align
	beqz a1, .L_write_err_align

	addi sp, sp, -32
	sw ra, 28(sp)
	sw s0, 24(sp)
	sw s1, 20(sp)
	sw s2, 16(sp)

	mv s0, a0
	mv s1, a1
	
	addi t0, a2, 1
	srli s2, t0, 1

	jal FpecWaitBusy

.L_write_loop:
	beqz s2, .L_write_done

	li t0, FPEC_CTLR
	lw t1, 0(t0)
	ori t1, t1, FPEC_CTLR_PG
	sw t1, 0(t0)

	lhu t1, 0(s1)
	sh t1, 0(s0)

	jal FpecWaitBusy

	li t0, FPEC_STATR
	lw t1, 0(t0)
	andi t2, t1, FPEC_STATR_EOP
	beqz t2, .L_write_chk_err
	li t2, FPEC_STATR_EOP
	sw t2, 0(t0)

.L_write_chk_err:
	li t0, FPEC_CTLR
	lw t1, 0(t0)
	andi t1, t1, ~FPEC_CTLR_PG
	sw t1, 0(t0)

	li t0, FPEC_STATR
	lw t1, 0(t0)
	andi t1, t1, FPEC_STATR_WRPRT
	bnez t1, .L_write_err_hw

	addi s0, s0, 2
	addi s1, s1, 2
	addi s2, s2, -1
	j .L_write_loop

.L_write_done:
	li a0, 0
	j .L_write_exit

.L_write_err_hw:
	li a0, -2
	j .L_write_exit

.L_write_err_align:
	li a0, -1
	ret

.L_write_exit:
	lw s2, 16(sp)
	lw s1, 20(sp)
	lw s0, 24(sp)
	lw ra, 28(sp)
	addi sp, sp, 32
	ret

FpecInitialize:
	ret
