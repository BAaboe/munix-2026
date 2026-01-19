; eax: amount to add
; ds:si memory address ; should maybe change this to es:di
; ret: ds:si new memory address
add_to_memory_address:
add esi, eax
mov eax, esi
and esi, 0xffff
and eax, 0xffff0000

jz .no_overflow

shr eax, 4
mov bx, ds
add ax, bx
mov ds, ax

.no_overflow:
ret


; ds:si zero terminated string ; should maybe change this to es:di
; cx byte count, including terminator
count_string_length:
xor cx, cx
.loop:
inc cx
cmp [es:di], 0
jnz .done

mov ax, 1

; preserving the ds and si, while adding ax to es:di
call add_to_memory_address

jmp .loop

.done:
ret
