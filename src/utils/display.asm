; 
; Display Utilities
;

; Clears the display
; Parameters:
; - None
; Return:
; - None
clear:
  pusha
  ; set video mode
  mov ah, 0x0
  mov al, 2
  int 0x10 ; video service

  ; reset cursor
  mov dh, 0
  mov dl, 0
  call moveCursor

  popa
  ret

; Moves cursor to input param position
; Parameters:
; - dh: row
; - dl: col
; Return:
; - None
moveCursor:
  pusha
  mov ah, 0x2 ; instr
  mov bh, 0x0
  int 0x10

  popa
  ret


; Prints a string to the display
; Parameters:
; - al: character to print
; Return:
; - None
newLine:
  pusha
  ; get cursor, ret dh: row, dl: col 
  mov ah, 0x3 ; instr
  mov bh, 0x0
  int 0x10
  
  add dh, 1   ; row, move 1 down
  mov dl, 0   ; go back left
  call moveCursor

  popa
  ret


; Prints a character to the display
; Parameters:
; - al: character to print
; Return:
; - None
printChar:
  pusha
  mov ah, 0xA
  mov bh, 0
  mov cx, 1
  int 0x10

  ; get cursor, ret dh: row, dl: col 
  mov ah, 0x3 ; instr
  mov bh, 0x0
  int 0x10
  
  add dl, 1   ; col, move 1 left
  call moveCursor

  popa
  ret


; Prints a string to the display
; Parameters:
; - bx: string address
; - cx: length
; Return:
; - None
printLine:
  pusha

  ; get cursor, ret dh: row, dl: col, cx is also changed by int
  push bx
  push cx
  mov ah, 0x3 ; instr
  mov bh, 0x0
  int 0x10
  pop cx
  pop bx

  push bp
  mov bp, bx
  ; write string
  mov ah, 0x13 ; instr
  mov al, 0
  mov bh, 0
  mov bl, COLOR_GRAY
  ; cx and bx for string and length
  int 0x10
  pop bp

  ; move cursor
  mov ah, 0x2 ; instr
  add dh, 1   ; row, move 1 down
  mov dl, 0   ; go back left
  mov bh, 0x0
  int 0x10

  popa
  ret