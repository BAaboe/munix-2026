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
mov ax, word [BPB_BytesPerSector]
add bx, ax

jnc .no_overflow

mov ax, es
add ax, 0x1000
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
push ds
xor dx, dx
mov ds, dx
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
pop ds

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
%include "bootloader/util.asm"
%include "bootloader/gdt.asm"
%include "bootloader/a20.asm"
%include "bootloader/fat12.asm"
%include "bootloader/multiboot2.asm"
%include "bootloader/elf.asm"


stage2:

; Need to load the kernel elf file into a place in memory where it won't
; be over written while makeing the proccess image.
; We are gonne place the procces image at 0x10000
; so if we place the elf file at 0x10000 + elf file size, this way we guatantee
; that we won't overwrite the proccess image.
; We do have to keep in mind that if the elf file gets to big we won't be able to fit it
; inside the usable memory. If this happens we should load the elf file, and the module,
; go to 32 bit move them out of the way, then make proccess image.

; First we figure out how big the file is
mov dl, [BPB_DriveNumber]
xor ax, ax
mov ds, ax
mov si, kernel_name

push ds
push si
call find_file
pop si
pop ds

; File size
mov eax, [es:di + 28]
; Cluster number of file
mov cx, [es:di + 26]
push cx

mov dx, kernel_memory_seg
mov ds, dx
mov si, kernel_memory_offset


call add_to_memory_address

; Apperently when we call int 13h we need that offset + 200h is <= 10000h.
; The easiest way I found to do this is by increasing segment by 1000h,
; and setting offset to 0. This means we in worst case we waste 64kb.
; Please tell me if there is a better way to do this.
mov ax, ds
add ax, 0x1000
and ax, 0xf000
mov es, ax
xor bx, bx


xor dx, dx
mov ds, dx

mov dl, [BPB_DriveNumber]
pop ax
push es
push bx
call read_clusters
pop bx
pop es

mov ax, es
mov ds, ax
mov si, bx

; ELF file should now be at 0x10000 + ELF file size
; Now we need to construct the proccess image

call construct_proccess_image

push eax


; Load the module file just after the kernel proccess image
xor ax, ax
mov ds, ax
mov si, mod_name
; Need to align the address such that bx + 0x200 !> 0x10000
add ecx, 0x1000
and ecx, 0xff000
shr ecx, 4
mov es, cx
xor bx, bx
mov dl, [BPB_DriveNumber]


push es
push bx
call read_file

; Get module end
xor eax, eax
mov ax, es
shl eax, 4
and ebx, 0xffff
add eax, ebx

; Get module start
pop bx
pop es

xor ecx, ecx
mov cx, bx
xor ebx, ebx
mov bx, es
shl ebx, 4
add ebx, ecx

xchg eax, ebx

; We place the multiboot2 tags at module end
push ebx
mov si, bx
and ebx, 0xf0000
shr ebx, 4
mov ds, bx
pop ebx

call set_multiboot2_tags

xor ebx, ebx
mov bx, ds
shl ebx, 4
add bx, si
push ebx

;Enter 32 bit
cli
cld

call load_gdt

pop ebx

mov eax, cr0
or al, 1
mov cr0, eax

pop ecx

jmp 0x08:pm_mode


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

mov eax, 0x36d76289 ; mb2 magic number

jmp ecx

cli
hlt

kernel_name: db "BOOT       /KERNEL     ", 0
mod_name: db "BOOT       /INITRD~1CPI", 0 
; I depated long and hard about if I should implement LFN for my fat12 reader,
; shorten the filename, or look for the SFN version in the code.
; I decided that I want my bootloader to work for munix without having to
; do changes to munix, but I couldn't be bothered to implement LFN, they are funky
; with how they store them (using UCS-2 characters, and having the filename in semi wrong order, and split up quit a lot),
; so I ended up with just using the SFN version.
; Should work

times 2048-($-$$) db 0
buffer:

memory_map_seg equ 0x0840
memory_map_offset equ 0x0000

kernel_memory_seg equ 0x1000
kernel_memory_offset equ 0x0000
