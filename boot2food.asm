org 0x7c00
bits 16

start:
    ; Set video mode 3 (80x25 color text mode)
    xor ah, ah
    mov al, 0x03
    int 0x10

    ; Set cursor to center of screen (row 12, col 17)
    mov ah, 0x02       
    xor bh, bh       
    mov dh, 12         ; Row 12 (middle of 25 rows)
    mov dl, 17         ; Column 17
    int 0x10

    ; Print welcome message with yellow text on blue background
    mov si, welcome_msg
    call print_string ; NEW


.wait_for_enter:
    xor ah, ah    
    int 0x16         
    cmp al, 0x0D     ; Check if the Enter key was pressed
    jne .wait_for_enter ; If not Enter, wait 


.game_start:
	call clear_screen_blue
	call draw_at_player
	call generate_random
	call draw_apple

.move_loop:

	mov ah, 0x02       
	mov bh, 0x00       ;
	mov dh, 0x00       ; Row 0 (top)
	mov dl, 0x78       ; Column 120 (rightmost column)
	int 0x10           

	mov si, score_label
	call print_string

	mov ax, [score]    ; Load score into AX
	call print_number  ; Convert and print number

	call check_time
	; call display_score
	call check_apple_position

    ; Wait for key press
    mov ah, 0x01
    int 0x16
    cmp al, 0
    jne .move_loop  

    ; Read scan code
    xor ah, ah
    int 0x16
    mov bl, ah

    ; Determine direction based on scan code
    cmp bl, 0x48  ; Up arrow
    je .move_up
    cmp bl, 0x50  ; Down arrow
    je .move_down
    cmp bl, 0x4B  ; Left arrow
    je .move_left
    cmp bl, 0x4D  ; Right arrow
    je .move_right
    jmp .move_loop

.move_up:
    call erase_at_player
    dec byte [player_y]
    call draw_at_player
    jmp .move_loop

.move_down:
    call erase_at_player
    inc byte [player_y]
    call draw_at_player
    jmp .move_loop

.move_left:
    call erase_at_player
    dec byte [player_x]
    call draw_at_player
    jmp .move_loop

.move_right:
    call erase_at_player
    inc byte [player_x]
    call draw_at_player
    jmp .move_loop



; Function clear screen and color it blue
clear_screen_blue:
    mov ah, 0x06       
    xor al, al       
    mov bh, 0x90       
    xor cx, cx     
    mov dx, 0x184F     
    int 0x10           
    ret


; Functions to modify player's position
; Function that draws the player
draw_at_player:
    mov dh, [player_y]
    mov dl, [player_x]
    mov al, '#'
    mov bl, 0x9E
    call draw_char
    ret

; Function that erases the player
erase_at_player:
    mov dh, [player_y]
    mov dl, [player_x]
    mov al, ' '
    mov bl, 0x9E
    call draw_char
    ret

; Function to erase apple
erase_apple:
    mov dh, [apple_y]
    mov dl, [apple_x]
    mov al, ' '
    mov bl, 0x9E
    call draw_char
    ret

; Function to print string with color ; NEW
print_string:
    lodsb              
    test al, al        ; Check for null terminator
    jz .done

    mov ah, 0x09       
    mov bh, 0x00       
    mov bl, 0x9E       
    mov cx, 1          
    int 0x10

    ; Get current cursor position
    mov ah, 0x03       
    mov bh, 0x00       
    int 0x10
    ; DL = current column, DH = current row

    inc dl             ; Move to next column
    

.set_cursor:
    ; Set new cursor position
    mov ah, 0x02       
    mov bh, 0x00       
    int 0x10

    jmp print_string

.done:
    ret
; Function that draws tha apple
draw_apple:
    mov dh, [apple_y]
    mov dl, [apple_x]
    mov al, '*'
    mov bl, 0x9C
    call draw_char
    ret


; Apple's life shouldn't exceed 3 seconds
check_time:
    xor ah, ah
    int 0x1A 
    ; Load stored tick count
    mov ax, [time_counter]      
    mov bx, [time_counter+2]    

    ; Compute difference: current CX:DX - stored CX:DX
    sub dx, ax
    sbb cx, bx

    ; Check if elapsed ticks >= 80
    cmp dx, 80
    jb .return

    ; if time is exceeded, regenerate apple
    call erase_apple
    call generate_random
    call draw_apple
    mov word [score], 0
.return:
    ret



; Function to determine new coordinate of apple
generate_random:
    ; Get system time
    xor ah, ah
    int 0x1A
    
    mov [time_counter], dx
    mov [time_counter+2], cx

    
    mov ax, dx      ; Low word of tick count
    add ax, cx      
    
    ; Generate X coordinate
    push ax         
    xor dx, dx      
    mov bx, 80      ; Divisor (gives range 0-79)
    div bx          
    mov [apple_x], dl   ; same as modulo
    
    ; Generate Y coordinate (0-24)
    pop ax          
    rol ax, 3       
    xor dx, dx      
    mov bx, 25      
    div bx          
    mov [apple_y], dl   
    ret

; Function to check for collision
check_apple_position:
    mov al, [player_x]
    cmp al, [apple_x]
    jne .no_collision
    
    mov al, [player_y]
    cmp al, [apple_y]
    jne .no_collision
    
    ; Collision detected
    inc byte [score]
    call generate_random  ; Just regenerate, don't check again
    call draw_apple
.no_collision:
    ret

; Draw a character
draw_char:

    ;   DH = row (Y)
    ;   DL = column (X)

    push ax
    push bx
    push dx

    mov ah, 0x02        
    xor bh, bh
    int 0x10

    mov ah, 0x09       
    mov cx, 1
    int 0x10

    pop dx
    pop bx
    pop ax
    ret

; Transoform number to ascii
print_number:
    push ax
    push bx
    push cx
    push dx

    xor cx, cx          ; Digit counter
    mov bx, 10

.next_digit:
    xor dx, dx
    div bx              ; AX ÷ 10, remainder is put iin DX
    push dx             ; Save remainder (digit)
    inc cx              ; Increment digit counter
    test ax, ax
    jnz .next_digit

.print_digits:
    pop dx
    add dl, '0'         ; Convert to ASCII
    mov ah, 0x0E        
    mov al, dl
    mov bl, 0x9E
    int 0x10
    loop .print_digits

    pop dx
    pop cx
    pop bx
    pop ax
    ret

;
welcome_msg db 'Welcome to F00D Game! Press enter to start...', 0 
score_label db 'Score: ', 0

player_x db 15 ;
player_y db 13 ;


apple_x db 12;
apple_y db 12;

score dw 0 ;

apple_counter db 0 ; to be used as a counter to prevent infinite apples

time_counter db 0 ; Life of the apple
times 510-($-$$) db 0
dw 0xaa55 
