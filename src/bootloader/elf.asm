
; ds:si: elf file address
; ret: eax: entry point
; ret: ecx: proccess image end address
construct_proccess_image:

push ds
push ax
xor ax, ax
mov ds, ax
mov ax, reading_elf_msg
pusha
call print
popa
pop ax
pop ds


; Check if elf file.
mov cx, 4

xor ax, ax
mov es, ax
mov di, elf_magic

push ds
push si

repe cmpsb

pop si
pop ds

jnz .no_elf

; Should maybe check more of the header, but I can't be botherd
; since I am also writing the OS/ELF files

mov eax, [ds:si + 24] ; Entry point
push eax
mov eax, [ds:si + 28] ; Program header offset
; mov bx, [ds:si + 42] ; Program header size ; I think this is always 32 in 32bit elf
mov cx, [ds:si + 44] ; Number of program headers
test cx, cx
jz .no_elf

push cx

; Need the address of the file later
push si
push ds

;push bx
call add_to_memory_address
;pop ax

; ds:si program header

.loop:
cmp dword [ds:si], 0x1 ; Check if is a load program
jnz .next_program_header

mov ecx, [ds:si + 20] ; p_memsz
mov eax, [ds:si + 8]  ; p_vaddr

; Get the proccess image end address
; The program address plus its size
push ds
xor di, di
mov ds, di
mov [proccess_image_end_addrsess], eax
add dword [proccess_image_end_addrsess], ecx
pop ds

; Place p_addr in es:di
mov edi, eax
and edi, 0xffff
and eax, 0xffff0000 
shr eax, 4
mov es, ax
xor ax, ax


push es
push di
rep stosb ; clear p_memsz bytes to zero starting at p_vaddr
pop di
pop es

mov ecx, [ds:si + 16] ; p_filesz
mov eax, [ds:si + 4]  ; p_offset

; Need the start of the file
pop bx
shl ebx, 16
pop bx

; Save program header address
push ds
push si

; set ds:si to file address
mov esi, ebx
and esi, 0xffff
shr ebx, 16
mov ds, bx

push si
push ds

call add_to_memory_address ; Find the start of the program

rep movsb ; Copy the program from file+p_offset to p_vaddr

pop bx
shl ebx, 16
pop bx
; ebx is now file address

pop si
pop ds
; ds:si is now program header address

push bx ; segment of file address
shr ebx, 16
push bx ; offset of file address

.next_program_header:
pop eax ; should be file address, don't need the value just the stack element below

pop cx
dec cx
test cx, cx
jz .done
push cx

push eax

mov eax, 32

call add_to_memory_address

jmp .loop

.done:
; Get the entry point
pop eax

; Get the total memory size of the proccess image
push ds
xor cx, cx
mov ds, cx
mov ecx, [proccess_image_end_addrsess]
pop ds

ret

.no_elf:
xor ax, ax
mov ds, ax
mov ax, not_elf_err
call print
cli
hlt

; TODO: This turned out a mess, use staticlly assigned memory to store important values, and not stack. It gets messy quick


proccess_image_end_addrsess: dd 0
not_elf_err: db "Error: Tried to construct proccess image from none ELF file or no program headers", 0
reading_elf_msg: db "Info: Creating proccess image from ELF file", 0
elf_magic: db 0x7f, "ELF" 
