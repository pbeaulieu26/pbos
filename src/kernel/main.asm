org 0x7E00
bits 16

jmp short main

;---------------- CODE Segment ----------------

%include "src/utils/display.asm"

main:
  ; write string
  mov cx, msglen
  mov bx, msg
  call printLine

  hlt

halt:
  jmp halt


;---------------- DATA Segment ----------------

; Constants
COLOR_GRAY equ 0x7

; Strings
msg db 'Inside the Kernel!', 0x0a
msglen equ $-msg