[bits 16]
org 7c00h

section .data
C_BLACK       equ 0h
C_WHITE       equ 15h
C_RED         equ 04h
C_GRAY        equ 12h
C_GRAY_LIGHT  equ 14h
C_GREEN_LIGHT equ 75h

BORDER_COLOR equ C_GRAY
BG_COLOR     equ C_GRAY_LIGHT

SCREEN_WIDTH     equ 320
SCREEN_HEIGHT    equ 200
BORDER_THICKNESS equ 10
VGA_SCREEN_SIZE  equ SCREEN_WIDTH * SCREEN_HEIGHT
SNAKE_SIZE       equ 8
SNAKE_STEP       equ 8

ZERO          equ 00h
VGA_MODE_13H  equ 13h
INT_VIDEO     equ 10h
VGA_SEGMENT   equ 0xA000
SET_CURSOR    equ 02h

section .text
init:
        xor ax, ax
        mov ds, ax
        mov es, ax

        mov ss, ax
        mov sp, 7c00h

        jmp main

background_init:
        push cx
        push ax
        push dx

        xor bx, bx

.pixel_loop:
        mov ax, bx
        xor dx, dx
        mov cx, SCREEN_WIDTH
        div cx

        cmp dx, BORDER_THICKNESS
        jl .draw_border

        cmp dx, SCREEN_WIDTH - BORDER_THICKNESS
        jge .draw_border

        cmp ax, BORDER_THICKNESS
        jl .draw_border

        cmp ax, SCREEN_HEIGHT - BORDER_THICKNESS
        jge .draw_border

        mov byte [es:bx], BG_COLOR
        jmp .next_pixel

.draw_border:
        mov byte [es:bx], BORDER_COLOR

.next_pixel:
        inc bx
        cmp bx, VGA_SCREEN_SIZE
        jne .pixel_loop

        pop dx
        pop ax
        pop cx
        ret

create_block:
.draw_block:
        push bx
        push cx
        push dx

        mov cx, SNAKE_SIZE

.row_loop:
        mov dx, SNAKE_SIZE

.col_loop:
        mov byte [es:bx], al
        inc bx
        dec dx
        jnz .col_loop

        add bx, SCREEN_WIDTH - SNAKE_SIZE
        loop .row_loop

        pop dx
        pop cx
        pop bx

        ret

erase:
        mov al, BG_COLOR
        call create_block
        ret

spawn_apple:
.try_again:
        mov ah, 00h
        int 1Ah

        mov ax, dx
        xor dx, dx
        mov bx, 37
        div bx
        shl dx, 3
        add dx, BORDER_THICKNESS
        push dx

        mov ax, cx
        xor dx, dx
        mov bx, 22
        div bx
        shl dx, 3
        add dx, BORDER_THICKNESS
        mov ax, dx
        shl ax, 6
        shl dx, 8
        add ax, dx
        pop dx
        add ax, dx
        mov [apple_pos], ax

        mov si, snake_body
        mov cx, [snake_len]
.check_body:
        cmp [si], ax
        je .try_again
        add si, 2
        loop .check_body
        cmp ax, di
        je .try_again

        mov bx, ax
        mov al, C_RED
        call create_block
        ret

check_self:
        push cx
        mov si, snake_body
        mov cx, [snake_len]
.next_segment:
        mov ax, [si]
        cmp ax, di
        je .hit
        add si, 2
        loop .next_segment
        pop cx
        clc
        ret
.hit:
        pop cx
        stc
        ret

main:
        mov al, C_GREEN_LIGHT

        mov ah, ZERO
        mov al, VGA_MODE_13H
        int INT_VIDEO

        mov ax, VGA_SEGMENT
        mov es, ax

        mov ch, 'w'

        call background_init
        mov bx, 45000

        mov al, C_GREEN_LIGHT
        call create_block

        mov [snake_body], bx
        push cx
        call spawn_apple
        pop cx

        call game_loop

game_loop:
        mov ah, 01h
        int 16h
        jz .main_loop

        mov ah, 00h
        int 16h

        mov ch, al

.main_loop:
        cmp ch, 's'
        je .move_down
        cmp ch, 'd'
        je .move_right
        cmp ch, 'a'
        je .move_left
        cmp ch, 'w'
        je .move_up

.move_left:
        mov di, bx
        sub di, SNAKE_STEP
        mov al, [es:di]
        jmp .check_collision
.move_right:
        mov di, bx
        add di, SNAKE_STEP
        push di
        add di, SNAKE_SIZE - 1
        mov al, [es:di]
        pop di
        jmp .check_collision
.move_up:
        mov di, bx
        sub di, SCREEN_WIDTH * SNAKE_STEP
        mov al, [es:di]
        jmp .check_collision
.move_down:
        mov di, bx
        add di, SCREEN_WIDTH * SNAKE_STEP
        push di
        add di, SCREEN_WIDTH * SNAKE_SIZE - 7
        mov al, [es:di]
        pop di
        jmp .check_collision

.check_collision:
        cmp al, BORDER_COLOR
        je .game_over

        call check_self
        jc .game_over

        cmp di, [apple_pos]
        jne .move_tail

        push cx
        inc word [snake_len]
        mov si, snake_body
        mov cx, [snake_len]
        dec cx
        add si, cx
        add si, cx
        mov [si], di
        call spawn_apple
        pop cx
        jmp .draw_head

.move_tail:
        push di
        mov bx, [snake_body]
        call erase
        pop di

        push cx
        mov si, snake_body
        mov cx, [snake_len]
        dec cx
        jcxz .store_head
.shift:
        mov ax, [si+2]
        mov [si], ax
        add si, 2
        loop .shift
.store_head:
        mov [si], di
        pop cx

.draw_head:
        mov bx, di
        mov al, C_GREEN_LIGHT
        call create_block

        push cx
        mov ah, 86h
        mov cx, 0001h
        mov dx, 86A0h
        int 15h
        pop cx

        jmp game_loop

.game_over:
        mov ah, SET_CURSOR
        mov bh, ZERO
        mov dh, 12
        mov dl, 15
        int INT_VIDEO

        mov si, game_over_msg

.print_loop:
        lodsb
        cmp al, ZERO
        je .dead_loop

        mov ah, 0Eh
        mov bh, 0
        mov bl, C_WHITE
        int INT_VIDEO

        jmp .print_loop

.dead_loop:
        mov ah, 00h
        int 16h
        cmp al, 'r'
        jne .dead_loop
        mov word [snake_len], 1
        jmp main

game_over_msg db "Game Over", ZERO

snake_body   equ 0x9000
snake_len    dw 1
apple_pos    dw 0

times 510 - ($ - $$) db ZERO
dw 0xAA55
