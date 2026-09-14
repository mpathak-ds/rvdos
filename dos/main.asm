;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    main.asm
;    14/09/26
;    mpathak
;    This module is the entry point.
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
	;Initialize USART1
	call UartInitialize

	la t4, welcome_banner
	call LibStrlen

	;Print boot banner.
	;la t4, welcome_banner
	call UartWriteString

main_loop: j main_loop

.data
welcome_banner:
    .string "RV-DOS Version 1.00\n"
