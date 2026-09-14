;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    str.asm
;    14/09/26
;    mpathak
;    String library.
;--*

.section .text
.global MainStartup

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
	;Try writing to uart and hang for now..
	li t3, 'H'
	call UartWriteChar
	
main_loop: j main_loop
