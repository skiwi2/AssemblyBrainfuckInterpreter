extern _malloc, _calloc, _printf, _fdopen, _fprintf, _scanf, _getchar, _putchar

%define STDERR                  2

%define NEWLINE_CODE            10
%define BF_MEMORY_CELL_AMOUNT   30000

%define BF_PROGRAM_END          255

%define JUMP_PAST_CODE          91
%define JUMP_BACK_CODE          93

segment _DATA public align=4 class=DATA use32

format_int              db      "%d", 0

write_mode              db      "w", 0

msg_memoryamount        db      "Enter how much memory (in bytes) your Brainfuck program needs: ", 0
msg_bfprogram           db      "Enter your Brainfuck program (use Enter exclusively to continue): ", 0

bfprogram_jump_table    times 43 dd bfprogram_invalidop, 
                        dd bfprogram_memory_inc, 
                        dd bfprogram_input, 
                        dd bfprogram_memory_dec,
                        dd bfprogram_output,
                        times 13 dd bfprogram_invalidop,
                        dd bfprogram_pointer_left,
                        dd bfprogram_invalidop,
                        dd bfprogram_pointer_right,
                        times 28 dd bfprogram_invalidop,
                        dd bfprogram_jump_past,
                        dd bfprogram_invalidop,
                        dd bfprogram_jump_back,
                        times 34 dd bfprogram_invalidop,
                        times 127 dd bfprogram_invalidop,       ; 128 (127 + next line) invalid ASCII characters
                        dd run_program_done                     ; if jump address is 255 (BF_PROGRAM_END), then we're done

error_outofmemory       db      "Fatal: The Operating System does not have enough memory available.", 0
error_programsize       db      "Fatal: The given Brainfuck program exceeded the given memory size.", 0
error_invalidop         db      "Fatal: An unsupported Brainfuck operation was found.", 0

segment _BSS public align=4 class=BSS use32

max_bf_program_size     resd 1

bf_program              resd 1    
bf_program_size         resd 1

bf_memory               resd 1

group DGROUP _BSS _DATA

segment _TEXT public align=1 class=CODE use32
        global  _main
_main:
    mov     ebp, esp                            ; save original stack pointer
;
; store Brainfuck program from console input
;    
    push    msg_memoryamount
    call    _printf
    add     esp, 4
    
    lea     eax, [ebp - 4]
    push    eax    
    push    format_int
    call    _scanf
    add     esp, 8    
    mov     eax, [ebp - 4]
    
    mov     [max_bf_program_size], eax
    
    inc     eax                                 ; reserve one extra byte for the BF_PROGRAM_END code
    
    push    eax
    call    _malloc
    add     esp, 4
    
    test    eax, eax
    jz      error_exit_outofmemory
    
    mov     [bf_program], eax
    
    call    _getchar                            ; consume newline
    
    push    msg_bfprogram
    call    _printf
    add     esp, 4
    
    mov     edi, [max_bf_program_size]
    xor     ebx, ebx
    
    mov     esi, [bf_program]
    
store_program_loop:
    call    _getchar
    
    cmp     eax, NEWLINE_CODE                   ; stop reading on newline
    jz      short store_program_done
    
    cmp     ebx, edi                            ; error if exceeded program size
    jz      error_exit_programsize
    
    mov     [esi + ebx], al
    
    inc     ebx
    jmp     short store_program_loop
    
store_program_done:
    mov     [esi + ebx], byte BF_PROGRAM_END    ; store program end special code

    mov     [bf_program_size], ebx
;
; zero-initialize BF memory cells
;
    push    dword 1
    push    BF_MEMORY_CELL_AMOUNT
    call    _calloc
    add     esp, 8
    
    test    eax, eax
    jz      error_exit_outofmemory
    
    mov     [bf_memory], eax
;
; run the BF program
;
    mov     esi, eax                            ; current memory address
    mov     edi, [bf_program]                   ; current program address    
    
run_program_loop:        
    movzx   eax, byte [edi]

    jmp     [bfprogram_jump_table + 4*eax]      ; addresses are dword, ASCII is translated to byte offsets

run_program_loop_end:
    inc     edi
    
    jmp     short run_program_loop
    
run_program_done:
    jmp     normal_exit
    
bfprogram_pointer_right:
    inc     esi
    
    jmp     run_program_loop_end
    
bfprogram_pointer_left:
    dec     esi
    
    jmp     run_program_loop_end
    
bfprogram_memory_inc:
    mov     al, [esi]
    inc     al
    mov     [esi], al
    
    jmp     run_program_loop_end
    
bfprogram_memory_dec:
    mov     al, [esi]
    dec     al
    mov     [esi], al
    
    jmp     run_program_loop_end
    
bfprogram_output:
    mov     al, [esi]
    
    push    eax                                 ; safe to do because eax is 000000xxh before the prior mov
    call    _putchar
    add     esp, 4
    
    jmp     run_program_loop_end
    
bfprogram_input:
    call    _getchar
    
    cmp     al, NEWLINE_CODE                    ; check if newline has been entered
    je      short bfprogram_input_newline
    
    mov     [esi], al
    
    jmp     run_program_loop_end
    
bfprogram_input_newline:
    dec     edi                                 ; set back program pointer
    
    jmp     run_program_loop_end                ; thus effectively ignore input
    
bfprogram_jump_past:
    mov     al, [esi]
    
    test    al, al                              ; check if memory cell is zero
    jnz     run_program_loop_end                ; if not zero, move to next instruction
;
; find matching ]
;
    mov     ebx, 1                              ; when counter reaches zero the ] is found where we need to jump past
    
bfprogram_jump_past_loop:
    inc     edi
    mov     al, [edi]
    
    cmp     al, JUMP_PAST_CODE
    jz      short bfprogram_jump_past_loop_found_jump_past
    
    cmp     al, JUMP_BACK_CODE
    jz      short bfprogram_jump_past_loop_found_jump_back
    
    jmp     short bfprogram_jump_past_loop
    
bfprogram_jump_past_loop_found_jump_past:
    inc     ebx
    
    jmp     short bfprogram_jump_past_loop
    
bfprogram_jump_past_loop_found_jump_back:
    dec     ebx
    
    test    ebx, ebx
    jz      run_program_loop_end                ; jumped over matching ]
    
    jmp     short bfprogram_jump_past_loop
    
bfprogram_jump_back:
    mov     al, [esi]
    
    test    al, al                              ; check if memory cell is zero
    jz      run_program_loop_end                ; if zero, move to next instruction
;
; find matching [
;
    mov     ebx, 1                              ; when counter reaches zero the [ is found where we need to jump back to
    
bfprogram_jump_back_loop:
    dec     edi
    mov     al, [edi]
    
    cmp     al, JUMP_BACK_CODE
    jz      short bfprogram_jump_back_loop_found_jump_back
    
    cmp     al, JUMP_PAST_CODE
    jz      short bfprogram_jump_back_loop_found_jump_past
    
    jmp     short bfprogram_jump_back_loop
    
bfprogram_jump_back_loop_found_jump_back:
    inc     ebx
    
    jmp     short bfprogram_jump_back_loop
    
bfprogram_jump_back_loop_found_jump_past:
    dec     ebx
    
    test    ebx, ebx
    jz      run_program_loop_end                ; jumped back to matching [
    
    jmp     short bfprogram_jump_back_loop
    
bfprogram_invalidop:
    jmp     error_exit_invalidop
    
error_exit_outofmemory:
    push    write_mode
    push    2
    call    _fdopen
    add     esp, 8

    push    error_outofmemory
    push    eax
    call    _fprintf
    add     esp, 8
    mov     eax, -1
    
    jmp     short exit
    
error_exit_programsize:
    push    write_mode
    push    2
    call    _fdopen
    add     esp, 8

    push    error_programsize
    push    eax
    call    _fprintf
    add     esp, 8
    mov     eax, -2
    
    jmp     short exit
    
error_exit_invalidop:
    push    write_mode
    push    2
    call    _fdopen
    add     esp, 8

    push    error_invalidop
    push    eax
    call    _fprintf
    add     esp, 8
    mov     eax, -3
    
    jmp     short exit
    
normal_exit:
    mov     eax, 0
    
exit:
    ret
    