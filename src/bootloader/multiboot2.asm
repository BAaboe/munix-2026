
; Ehhh idk, this is not tested yet, and I have a feeling it won't work, but need to read kernel elf file fist and transfere control before I can test
; ds:si boot info address
; edi module start address
; ecx module end address
; ret es:di actual boot info address
set_up_boot_information:
; Find first 8 byte aligned address
; di = di + (8 - (di % 8))
mov ax, si
mov cx, 8
div cx
mov ax, 8
sub ax, dx
call add_to_memory_address


; Save the start of the boot information
push ds
push si

xor ecx, ecx

; Module
push cx
mov [ds:si], 3
; Load the start address
xor eax, eax
mov ax, es
shl eax, 8
add eax, edi
mov [ds:si +8], eax
; Load the end address
xor eax, eax
mov ax, es
shl eax, 8
add eax, ebx
mov [ds:si +12], eax

push ds
push si
mov ax, 32
call add_to_memory_address ; get start of string
mov ax, ds
mov es, ax
mov di, si

xor ax, ax
mov ds, ax
mov si, module_string

push ds
push si
call count_string_length
pop si
pop ds

push cx
rep movsb
pop cx

pop si
pop ds

add cx, 32
xor ax, ax
mov ax, cx
mov [ds:si + 4], eax
pop cx
add cx, ax ; Update total number of bytes
push cx
call add_to_memory_address


; Image load base address
mov dword [ds:si], 21
mov dword [ds:si + 4], 12
mov dword [ds:si + 8], 0x10000

mov ax, 12
pop cx ; Update total number of bytes
add cx, ax
push cx
call add_to_memory_address

;Framebuffer TODO, do this more dynamicyl
mov dword [ds:si], 8
mov dword [ds:si + 4], 32
mov dword [ds:si + 8], 0xB8000
mov dword [ds:si + 16], 160
mov dword [ds:si + 20], 80
mov dword [ds:si + 24], 25
mov byte [ds:si + 28], 2
mov byte [ds:si + 29], 2

mov ax, 32
pop cx
add cx, ax
push cx
call add_to_memory_address


; Stop entry
mov dword [ds:si], 0
mov dword [ds:si + 4], 8
xor ecx, ecx
pop cx
add cx, 8

pop si
pop ds
mov [ds:si], ecx

ret






module_string: db "initrd.cpio    ",0
; Keepsake
;xor cx, cx ; Keep track of the size
;
;mov ax, 8
;add cx, ax
;call add_to_memory_address
;
;; BIOS Boot device
;mov dword [ds:si], 5
;mov dword [ds:si + 4], 20
;xor edx, edx
;mov dx, [BPB_DriveNumber]
;mov [ds:si + 8], edx
;mov dword [ds:si + 12], 0xffffffff ; We don't use partitions
;mov dword [ds:si + 16], 0xffffffff
;
;mov ax, 20
;add cx, ax
;call add_to_memory_address
;
;
;; Memory map
;mov dword [ds:si], 6
;mov dword [ds:si + 8], 24 ; Entry size
;mov dword [ds:si + 12], 0 ; entry version
;
;; Get memory map from bios
;mov ax, ds
;mov es, ax
;mov di, si
;mov ax, 16
;call add_to_memory_address
;
;
;xor cx, cx
;push cx
;mov edx, 0x534D4150
;xor ebx, ebx
;.mm_loop:
;mov ecx, 24
;xor eax, eax
;mov ax, 0xe820
;int 0x15
;jc .mm_carry
;
;; Keep track of number of bytes total
;pop cx
;add cx, 24
;push cx
;
;cmp ebx, 0
;jz .mm_done
;
;; Increment the memory address by 24
;push ds
;push si
;mov ax, es
;mov ds, ax
;mov si, di
;mov ax, 24
;call add_to_memory_address
;mov ax, ds
;mov es, ax
;mov si, di
;pop si
;pop ds
;
;jmp .mm_loop
;
;.mm_carry:
;cmp ah, 0x86
;jne .mm_done
;
;.mm_done:
;
;xor eax, eax
;pop cx
;; cx should be the total number of bytes for all entries
;; and all entries should be loaded to the correct place, I hope...
;add cx, 16 ; Add the size of the tag
;mov ax, cx
;mov [ds:si + 4], eax
;
;pop cx ; Update total number of bytes
;add cx, ax
;push cx
;
;call add_to_memory_address
