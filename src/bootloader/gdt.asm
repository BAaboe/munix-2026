; GDT

gdt:
dq 0 ; 0 entry

; Ring 0 code
dw 0xffff ; Limit
dw 0 ; Base
db 0
db 0b10011111 ; Access Byte
db 0b11001111 ; Flags and limit
db 0 ; Base


; Ring 0 data
dw 0xffff ; Limit
dw 0 ; Base
db 0
db 0b10010011 ; Access Byte
db 0b11001111 ; Flags and limit
db 0 ; Base
gdt_end:


gdtr:
	dd 0
	dw 0

load_gdt:
; Set the size
xor eax, eax
mov eax, gdt_end+1
sub eax, gdt
mov [gdtr], ax

; Set the offset
xor eax, eax
mov ax, ds
shl eax, 4
add eax, gdt
mov [gdtr + 2], eax

lgdt [gdtr]
ret
