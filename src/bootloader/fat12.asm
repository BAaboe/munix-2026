; dl: drive
; ds:si file name
; es:bx memory address
; ret: ax:cx file size
read_file:
push dx
push es
push bx
call find_file

mov ax, [es:di + 26]
mov [cluster], ax
mov cx, [es:di + 28]
mov ax, [es:di + 30]
pop bx
pop es
pop dx

push ax
push cx

mov ax, [cluster]

call read_clusters

pop cx
pop ax

ret


; dl: drive
; ds:si: filename
; ret: es:di contains file entry
find_file:
push dx

; Find what sector the root directory is on
; ax = ReservedSectors + NumberOfFats*SectorsPerFat
xor ax, ax
mov ax, [BPB_SectorsPerFat]
mul byte [BPB_NumberOfFats]
add ax, word [BPB_ReservedSectors]

; Find how many sectors the root directory is
push ax ; Save ax since mul and div uses ax
; cx = (RootEntries*32 + BytesPerSector-1)/BytesPerSector
mov ax, word [BPB_RootEntries]
mov cx, 32
mul cx
add ax, word [BPB_BytesPerSector]
dec ax
div word [BPB_BytesPerSector]
mov cx, ax

pop ax

; Find when the root directory ends, need it later
add cx, ax
mov [root_end_lba], cx

; Restor drive number
pop dx

; Start by looking at root directory
mov byte [root_dir], 1

; Jump over the increment in lba/cluster
jmp .read_next_sector

; Set up for read_sector
.get_next_sector:
mov [bytes_read], 0
cmp [root_dir], 1
jnz .not_root

; Read the next sector of the root directory
inc ax

; If we are at the end of the root directory we didn't find the file
cmp ax, [root_end_lba]
push ax
mov al, '0'
out 0xe9, al
pop ax
jz .entry_not_found

jmp .read_next_sector

.not_root:

pusha
call get_next_cluster_number
popa
mov ax, [cluster]

; End of directory table, so file not found
cmp ax, 0xff8
push ax
mov al, '1'
out 0xe9, al
pop ax
jge .entry_not_found

sub ax, 2
add ax, [root_end_lba] ; Get cluster lba

; Read the sector into memory
.read_next_sector:
mov di, 1
xor bx, bx
mov es, bx
mov bx, buffer

call read_sectors

mov di, buffer
.lookup_loop:
; Check if at the end of directory
cmp [es:di], 0
push ax
mov al, '2'
out 0xe9, al
pop ax
jz .entry_not_found


mov cx, 11
push di
push si
cld
repe cmpsb
pop si
pop di
jz .entry_found

; Go to next entry
add di, 32

mov cx, word [bytes_read]
add cx, 32
cmp cx, 512
mov [bytes_read], cx
jz .get_next_sector

jmp .lookup_loop

.entry_found:

add si, 11
cmp byte [ds:si], '/'
jz .find_sub_entry

; Found correct file
; File entyr should be loaded to es:di
ret

.find_sub_entry:
add di, 11
cmp [es:di], 0x10 
jnz .entry_not_found ; If we did not find a directory entry we didn't find what we wanted

add di, 15 ; 26-11
mov ax, [es:di] ; load the number for the first cluster in the sub directory
mov [cluster], ax
mov [root_dir], 0

inc si ; si points now to the new sub directory/file name.

sub ax, 2
add ax, [root_end_lba] ;Get the cluster lba
mov [bytes_read], 0

jmp .read_next_sector


.entry_not_found:
mov ax, file_not_found
call print
cli
hlt

 
; dl: drive
; ax: first cluster
; es:bx memory address
read_clusters:
.read_loop:
mov [cluster], ax
sub ax, 2
add ax, [root_end_lba] ; Find lba of fisrt cluster, assuming that find_file has been called previously.
mov di, 1

call read_sectors

pusha
call get_next_cluster_number
popa

cmp word [cluster], 0xff8
jl .read_loop

ret


; [cluster]: current cluster
; dl: drive
; OBS!!!! This will overwrite buffer
; ret: [cluster] is the new cluster number
get_next_cluster_number:

; Get the fat table from the disk
xor ax, ax
mov es, ax
mov ax, word [BPB_ReservedSectors]
mov di, word [BPB_SectorsPerFat]
mov bx, buffer
call read_sectors

; Index into fat table ax*1.5
mov bx, buffer
mov ax, [cluster]
add bx, ax
shr ax, 1
add bx, ax

mov ax, word [bx]
push ax

; If the cluster number is even we read the current byte plus half of the next
; If the cluster number is odd we read half of the current byte plus the next byte
mov ax, [cluster]
and ax, 1
test ax, ax

jz .even

.odd:
pop ax
shr ax, 4
and ax, 0xfff
jmp .eo_done

.even:
pop ax
and ax, 0xfff

.eo_done:
mov [cluster], ax

ret


bytes_read: dw 0
root_dir: db 0
root_end_lba: dw 0
end_of_directory: db 0
cluster: dw 0
