; eax: module start
; ebx: module end
; ds:si: tags address
set_multiboot2_tags:
push ds
push ax
xor ax, ax
mov ds, ax
mov ax, multiboot2_msg
pusha
call print
popa
pop ax
pop ds

push eax
push ebx

add si, 16
and si, 0xfff0

call add_to_memory_address

;Retrive the module start and module end
pop ebx
pop eax

; Save the address of the multiboot2 tags
push ds
push si

push ebx
push eax

xor eax, eax

; Skip the first entry, don't know the total size yet
mov ax, 8
push ds
xor cx, cx
mov ds, cx
add [multiboot2_size], ax
pop ds
call add_to_memory_address

; Module tag
pop eax
pop ebx
mov word [ds:si], 3 ; Set the tag type
mov [ds:si + 8], eax ; Set the module start address
mov [ds:si + 12], ebx ; Set the module end address

; Get the module string length
xor ecx, ecx
push ds
push si
mov ds, cx
mov si, module_string
call count_string_length

pop si
pop ds

; Set the length of the tag as 64 + string length
xor eax, eax
mov ax, 32
add ax, cx
mov [ds:si + 4], eax

push ds
push si
mov ax, 16
call add_to_memory_address

; Set up the registers for memcopy
; Need dst to be es:di
; and src to be ds:si
mov ax, ds
xor bx, bx
xchg ax, bx
mov ds, ax
mov es, bx

mov ax, si
mov bx, module_string
xchg ax, bx
mov si, ax
mov di, bx

; Do the copy
rep movsb

pop si
pop ds

; Update the total size and inrement the address
mov eax, [ds:si + 4]
push ds
xor cx, cx
mov ds, cx
add [multiboot2_size], ax
pop ds
call add_to_memory_address

; Framebuffer
mov dword [ds:si], 8 ; type
mov dword [ds:si + 4], 32
mov dword [ds:si + 8], 0xB8000
mov dword [ds:si + 16], 160
mov dword [ds:si + 20], 80
mov dword [ds:si + 24], 25
mov byte [ds:si + 28], 2
mov byte [ds:si + 29], 2

; Update the total size and inrement the address
mov eax, [ds:si + 4]
push ds
xor cx, cx
mov ds, cx
add [multiboot2_size], ax
pop ds
call add_to_memory_address

; Stop entry
mov dword [ds:si], 0
mov dword [ds:si + 4], 8

; Update the total size
mov eax, [ds:si + 4]
push ds
xor cx, cx
mov ds, cx
add [multiboot2_size], ax
pop ds


; Restore the address of the tag
xor ecx, ecx
mov ds, cx
mov cx, [multiboot2_size]

pop si
pop ds

mov [ds:si], ecx

ret


multiboot2_size: dw 0
module_string: db "initrd.cpio    ",0
multiboot2_msg: db "Info: Making multiboot2 tags", 0
