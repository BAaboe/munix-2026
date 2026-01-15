; THIS IS THE MBR SECTOR
[BITS 16]
ORG 0x7c00

; Fat header stuff jmp short boot_code
jmp short boot_code
nop
; BIOS Paramter block
BPB_OEM					db 'MUNIX   '
BPB_BytesPerSector		dw 512
BPB_SectorsPerCluster	db 1
BPB_ReservedSectors		dw 4
BPB_NumberOfFats		db 2
BPB_RootEntries			dw 224
BPB_TotalSectors		dw 2880
BPB_MediaDescriptor		db 0xf0
BPB_SectorsPerFat		dw 9
BPB_SectorsPerTrack		dw 18
BPB_NumberOfHeads		dw 2
BPB_HiddenSectors		dd 0
BPB_LargeTotalSectors	dd 0

; Extended Boot Record
BPB_DriveNumber			db 0
BPB_Reserved			db 0
BPB_BootSignatur		db 0x29
BPB_VolumeSerialNum		dd 1234
BPB_VolumeLable			db 'boot loader'
BPB_FileSystemType		db 'FAT12   '



boot_code:
; Set up the segments
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax

; Set up the stack
mov sp, 0x7c00
mov bp, sp

; Align properly, some bios load at 0x7c0:0x0000 instead of 0x0000:0x7c00
jmp 0x00:aligned


aligned:

; Save the drive number
mov [BPB_DriveNumber], dl

; Get disk geometry
test dl, 0x80
jnz .hard_drive

.floppy_drive:
mov [BPB_TotalSectors], word 2880
mov [BPB_SectorsPerTrack], 18
mov [BPB_NumberOfHeads], 2
jmp .geometry_done

.hard_drive:
mov di, 0x00
mov dl, [BPB_DriveNumber]
mov ah, 0x08
int 0x13

inc dh
mov [BPB_NumberOfHeads], dh

mov ax, cx
and cx, 0x3f
mov [BPB_SectorsPerTrack], cl

xor cx, cx
mov cl, ah
shr al, 6
mov ch, al
inc cx

mov ax, [BPB_SectorsPerTrack]
mul cx
mov cx, [BPB_NumberOfHeads]
mul cx
mov [BPB_TotalSectors], ax


.geometry_done:

mov dl, [BPB_DriveNumber]
mov ax, 1
mov di, 3
mov bx, 0x7e00
call read_sectors

jmp stage2

cli
hlt

; Reads sector from disk
; ax: lba
; dl: drive
; di: number of sectors to read
; es:bx: buffer
;
read_sectors:
.loop:
push ax
push dx

call lba_to_chs


pop ax
mov dl, al

mov ah, 0x02
mov al, 1


pusha
int 0x13
popa

; TODO: Maybe try more than once before giving up
jc .disk_error

dec di
add bx, [BPB_BytesPerSector]

jnc .no_overflow

mov ax, es
add ax, 0x100
mov es, ax

.no_overflow:

pop ax
inc ax


test di, di
jnz .loop
ret

.disk_error:
call disk_error
;
; Converts LBA to CHS address
; ax: lba
; Returns:
; cx = [0-6] sector, [7-15] cylinder
; dh = head
;
lba_to_chs:
; Follows https://en.wikipedia.org/wiki/Logical_block_addressing#CHS_conversion
; Get the sector number
xor dx, dx
div word [BPB_SectorsPerTrack]
mov cx, dx
inc cx

; Get the head number
xor dx, dx
div word [BPB_NumberOfHeads]
mov dh, dl

; Get the track number
mov ch, al
shl ah, 6
or cl, ah

ret

;
; Prints
; ds:ax: string
;
print:
mov si, ax
.loop:
lodsb
cmp al, 0
jz .done

mov ah, 0x0e

xor bx, bx

int 0x10

jmp .loop

.done:
mov ah, 0x0e
mov al, 10
int 0x10
mov al, 0x0d
int 0x10
ret

disk_error:
xor ax, ax
mov ds, ax
mov ax, disk_read_error_msg
call print

cli
hlt

happy:
push ax
push ds
xor ax, ax
mov ax, ds
mov ax, happy_msg
call print
pop ds
pop ax
ret


disk_read_error_msg: db "Could not read disk",0
happy_msg: db ":)", 0
file_not_found: db "File not found", 0



times 510-($-$$) db 0
db 0x55, 0xaa

; THIS IS THE SECTORS AFTER MBR

mm_error_msg: db "INT 15h AX=E820h not supported", 0
%include "bootloader/gdt.asm"
%include "bootloader/a20.asm"
%include "bootloader/fat12.asm"


stage2:
mov dl, [BPB_DriveNumber]
mov ax, kernel_memory_seg
mov es, ax
mov bx, kernel_memory_offset
xor ax, ax
mov ds, ax
mov si, file_name

call read_file

cli
hlt

;Use bios to find info about system
;TODO

; Get memory map
mov ax, memory_map_seg
mov es, ax
mov di, memory_map_offset

xor bp, bp
add di, 24 ; First entry contains the number of entries

; Magic number :)
mov edx, 0x534D4150
xor ebx, ebx

.mm_loop:
mov ecx, 24
; Some BIOSes needs the top 16bits of eax to be zero
xor eax, eax
mov ax, 0xE820
int 0x15
jc .mm_carry
inc bp
add di, 24
test ebx, ebx
jnz .mm_loop

.mm_carry:
cmp ah, 0x86
jne .mm_done

; Don't want to end up here
xor ax, ax
mov ds, ax
mov ax, mm_error_msg
call print
cli
hlt

.mm_done:
mov di, memory_map_offset
mov [es:di], bp

;Enter 32 bit
cli
cld

call load_gdt

mov eax, cr0
or al, 1
mov cr0, eax


jmp 0x08:pm_mode

cli 
hlt

[BITS 32]
;Trampoline
pm_mode:
;Set segment registers
mov ax, 0x10
mov ds, ax
mov es, ax
mov ss, ax
mov fs, ax
mov gs, ax
mov esp, 0x7c00

mov eax, kernel_memory_seg
shl eax, 4
add eax, kernel_memory_offset
jmp eax

cli
hlt

file_name: db "BOOT       /KERNEL     ", 0
times 2048-($-$$) db 0
buffer:

memory_map_seg equ 0x0840
memory_map_offset equ 0x0000

kernel_memory_seg equ 0x1000
kernel_memory_offset equ 0x0000
