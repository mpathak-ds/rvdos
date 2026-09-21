#
#Standard native library.
#

.section .text.entry
.global _start
.global WriteString
.global ExitProgram
.global ReadChar
.global WriteChar

#
#Entry point gen
#
_start:
	lla sp, stack_top
	call AppMain
	call ExitProgram

.section .text

WriteString:
	mv a2, a0
write_str_loop:
	lbu a1, 0(a2)
	beqz a1, write_str_done
	#ecall 0 is writechar
	li a0, 0
	ecall
	addi a2, a2, 1
	j write_str_loop

write_str_done:
	ret

ExitProgram:
	li a0, 2
	ecall
	ret

ReadChar:
	li a0, 1
	ecall
	#a0 now has char
	ret

WriteChar:
	mv a1, a0
	li a0, 0
	ecall
	ret

.bss
.balign 16
.space 512
.balign 16
stack_top:
