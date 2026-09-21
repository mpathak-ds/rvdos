#
#Same example as main.c but in assembly..
#swap main.c for main.s in Makefile for trying this one out
#

.text
.section .rodata
.align	2
.my_string:
	.string	"Hello from a native binary!\nPress any key to exit."
	.text
	.align	1

.global AppMain
AppMain:
	addi sp, sp, -16
	sw ra, 12(sp)
	sw s0, 8(sp)
	addi s0, sp, 16
	
	lla	a0, .my_string
	call WriteString
	call ReadChar
	
	lw ra, 12(sp)
	lw s0, 8(sp)
	addi sp, sp, 16
	jr ra
