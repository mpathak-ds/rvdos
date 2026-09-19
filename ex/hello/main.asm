ORG 100H

section .text

start:
	MOV DX, MSG
	MOV AH, 09H
	INT 21H
	
	MOV AL, 42H
	MOV AH, 4CH
	INT 21H
	
section .data
	MSG db 'Hello World!$'
