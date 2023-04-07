org 0x7C00
bits 16

;
; FAT 12 header
;

; Boot parameter block
jmp short main                                                 ; 3 bytes: jump + nop
nop

bdb_oem                               db 'MSWIN4.1'            ; 8 bytes
bdb_bytes_per_sector                  dw 512 	                 ; The number of Bytes per sector (remember, all numbers are in the little-endian format).
bdb_sectors_per_cluster               db 1                     ; Number of sectors per cluster.
bdb_num_reserved_sectors              dw 1                     ; Number of reserved sectors. The boot record sectors are included in this value.
bdb_num_fat                           db 2                     ; Number of File Allocation Tables (FAT's) on the storage media. Often this value is 2.
bdb_num_root_dir_entries              dw 0xE0                  ; Number of root directory entries (must be set so that the root directory occupies entire sectors).
bdb_total_sectors                     dw 2880                  ; The total sectors in the logical volume. If this value is 0, it means there are more than 65535 sectors in the volume, and the actual count is stored in the Large Sector Count entry at 0x20.
                                                               ; 2880 * 512 bytes = 1.44mb
bdb_media_desc_type                   db 0xF0                  ; This Byte indicates the media descriptor type. 3.5" floppy disk
bdb_sectors_per_fat                   dw 9                     ; Number of sectors per FAT. FAT12/FAT16 only.
bdb_sectors_per_track                 dw 18                    ; Number of sectors per track.
bdb_num_heads                         dw 2                     ; Number of heads or sides on the storage media.
bdb_hidden_sectors                    dd 0                     ; Number of hidden sectors. (i.e. the LBA of the beginning of the partition.)
bdb_large_sector_count                dd 0                     ; Large sector count. This field is set if there are more than 65535 sectors in the volume, resulting in a value which does not fit in the Number of Sectors entry at 0x13.

; Extended boot record
ebr_drive_number	                    db 0                     ; Drive number. The value here should be identical to the value returned by BIOS interrupt 0x13, or passed in the DL register; i.e. 0x00 for a floppy disk and 0x80 for hard disks. This number is useless because the media is likely to be moved to another machine and inserted in a drive with a different drive number.
ebr_reserved	                        db 0                     ; Flags in Windows NT. Reserved otherwise.
ebr_signature	                        db 0x29                  ; Signature (must be 0x28 or 0x29).
ebr_serial_number	                    db 0x4, 0x3, 0x2, 0x1    ; VolumeID 'Serial' number. Used for tracking volumes between computers. You can ignore this if you want.
ebr_volume_label	                    db 'PBOS       '         ; Volume label string. This field is padded with spaces. 11 bytes
ebr_system_id	                        db 'FAT12   '            ; System identifier string. This field is a string representation of the FAT file system type. It is padded with spaces. The spec says never to trust the contents of this string for any use. 8 bytes


;---------------- Code Segment ----------------
main:
  ; setup data segment
  mov ax, 0
  mov ds, ax
  mov es, ax

  ; setup stack
  mov ss, ax
  mov sp, 0x7C00 ; stack grows downwards 
  mov bp, 0x7C00 ; stack grows downwards 

  ; set video mode
  mov ah, 0x0
  mov al, 2
  int 0x10 ; video service

  ; set cursor
  mov ah, 0x1
  mov ch, 0xF ; normal blink
  mov cl, 0xF ;
  int 0x10

  ; write string
  mov cx, msglen
  mov bx, msg
  call printLine
  call printLine
  call printLine
  call printLine
  call printLine

  call newLine
  call newLine
  call newLine

  mov al, 'A'
  call printChar
  mov al, 'A'
  call printChar
  call newLine

  mov ax, 1 ; read block 1
  mov [ebr_drive_number], dl
  mov cl, 1 ; 1 block to read
  mov bx, 0x7E00
  call readDisk

  mov al, 'A'
  call printChar
  call newLine

  jmp 0x7E00

  hlt

halt:
  jmp halt

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

; 
; Input Utilities
;

; Waits for a key press.
; Parameters:
; - None
; Return:
; - al: Key pressed
getKeyPress:
  push bx
  push ax

  mov ah, 0
  int 16h ; wait for key press

  pop bx ; ax from start
  mov ah, bh ; restore ah
  pop bx 
  ret


; 
; Error handlers
;

; Writes an error message then waits for input and reboots the machine
; Parameters:
; - None
; Return:
; -None
readError:
  mov bx, read_error
  mov cx, read_error_len
  call printLine
  jmp .reboot

; Reboots the machine at start of BIOS
.reboot:
  ; get input char
  call getKeyPress

  ; jump to bios start
  jmp 0xFFFF:0

.halt:
  cli ; disable interruupts
  hlt


; 
; Disk Utilities
;

; Translate logical block adress to physical (Cylinder-Head-Sector address)
; The block adress is basically the sector number starting from 0 
; Parameters:
; - ax: lba adress
; Return:
; -dh = head number
; -cx = [6:15] : cylinder number
; -cx = [0:5]  : sector number
lbaToChs:
  push ax
  push dx

  ; Tip: div => dx:ax / bx
  ; - ax: div
  ; - dx: remainder

  ; example LBA  = 20 : 00000000 00010100 

  ;
  ; Sector
  ;

  ; sector = (LBA % sectors_per_track) + 1 (+1 because it is 0 based)
  xor dx, dx ; dx = 0
  ; ax = LBA / sectors_per_track
  ; dx = LBA % sectors_per_track
  div word [bdb_sectors_per_track] ; ax = 00000000 00000001 (20 / 18)
                                   ; dx = 00000000 00000010 (20 % 18 = remainder 2)

  mov cx, dx ; cx = 00000000 00000010
  inc cx     ; cx = 00000000 00000011

  ;
  ; Head and Cylinder
  ; 

  ; head = (LBA / sectors_per_track) % heads
  ; cylinder = (LBA / sectors_per_track) / heads
  xor dx, dx ; dx = 0
  ; ax = (LBA / sectors_per_track) / heads
  ; dx = (LBA / sectors_per_track) % heads
  div word [bdb_num_heads] ; ax = 00000000 00000000 (1 / 2)
                           ; dx = 00000000 00000001 (1 % 2 = remainder 1)
  mov dh, dl ; dx = 00000001 00000000

  shl ax, 6 ; ax = 00000000 00000000
  or cx, ax ; cx = 00000000 00000011

  pop ax
  mov dl, al ; restore DL
  pop ax
  ret


; Read sector (block) from disk
; Parameters:
; -ax = LBA address
; -dl = drive number
; -cl = number of blocks to read
; -es:bx : address to store read sector 
; Return:
; -None
readDisk:
  push ax
  push bx
  push cx
  push dx
  push di

  push cx ; save number of blocks to read on stack
  call lbaToChs
  pop ax ; from stack, take cx value of number of blocks to read
  
  mov ah, 0x2 ; ah = 0x2 read from disk
  mov di, 3 ; counter of 3 retries

  .retry:
    pusha
    
    push ax
    mov ah, 0x2
    stc
    int 0x13 ; read from disk int
    pop ax
    jnc .done

    ; failed
    popa
    call resetDisk
    dec di
    cmp di, 0
    jnz .retry

  .fail:
    ; attempts all failed
    jmp readError

  .done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    ret

; Read sector (block) from disk
; Parameters:
; -dl = drive number
; Return:
; -None
resetDisk:
  pusha
  mov ah, 0x0
  stc
  int 0x13
  jc read_error
  popa
  ret


;---------------- DATA Segment ----------------

; Constants
COLOR_GRAY equ 0x7

; Strings
msg db 'HELLO WORLD', 0x0a
msglen equ $-msg

read_error db 'Could not read disk after 3 attempts', 0x0a
read_error_len equ $-read_error


;---------------- End of BootSector ----------------
times 510 - ($-$$) db 0
dw 0xAA55 ; bootloader signature