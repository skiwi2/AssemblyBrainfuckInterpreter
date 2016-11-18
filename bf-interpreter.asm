extern _malloc, _calloc, _fdopen, _fprintf, _getchar, _putchar, _fopen, _fseek, _ftell, _rewind, _fgetc, _fclose

%define STDERR                  2
%define SEEK_END                2
%define EOF                     -1    

%define BF_MEMORY_CELL_AMOUNT   30000

%define BF_PROGRAM_END          255

%define JUMP_PAST_CODE          91
%define JUMP_BACK_CODE          93

section .data

write_mode              db      "w", 0
read_mode               db      "r", 0

bfprogram_jump_table    times 43 dd run_program_loop_end, 
                        dd bfprogram_memory_inc, 
                        dd bfprogram_input, 
                        dd bfprogram_memory_dec,
                        dd bfprogram_output,
                        times 13 dd run_program_loop_end,
                        dd bfprogram_pointer_left,
                        dd run_program_loop_end,
                        dd bfprogram_pointer_right,
                        times 28 dd run_program_loop_end,
                        dd bfprogram_jump_past,
                        dd run_program_loop_end,
                        dd bfprogram_jump_back,
                        times 34 dd run_program_loop_end,
                        times 127 dd run_program_loop_end,      ; 128 (127 + next line) invalid ASCII characters
                        dd run_program_done                     ; if jump address is 255 (BF_PROGRAM_END), then we're done

error_noargument        db      "Fatal: No argument was provided.", 0
error_notexist          db      "Fatal: The file does not exist.", 0
error_outofmemory       db      "Fatal: The Operating System does not have enough memory available.", 0

section .bss

file_name               resd 1

bf_program_size         resd 1
bf_program              resd 1    

bf_memory               resd 1

section .text
        global  _main
_main:
    mov     ebp, esp                            ; save original stack pointer
;
; read command line arguments
;
    mov     eax, [ebp + 4]                      ; argc
    
    cmp     eax, 1
    je      error_exit_noargument
    
    mov     eax, [ebp + 8]                      ; *argv    
    mov     eax, [eax + 4]                      ; argv[1]
    
    mov     [file_name], eax
;
; open file
;
    push    read_mode
    push    eax
    call    _fopen
    add     esp, 8
    
    test    eax, eax
    jz      error_exit_notexist
    
    mov     edi, eax                            ; store file pointer
;
; get file size
;
    push    SEEK_END
    push    0
    push    edi
    call    _fseek
    add     esp, 12
    
    push    edi
    call    _ftell
    add     esp, 4
    
    inc     eax                                 ; reserve one extra byte for the BF_PROGRAM_END code
    mov     [bf_program_size], eax
;
; rewind file
;
    push    edi
    call    _rewind
    add     esp, 4
;
; read Brainfuck program from file
;            
    push    dword [bf_program_size]
    call    _malloc
    add     esp, 4
    
    test    eax, eax
    jz      error_exit_outofmemory
    
    mov     [bf_program], eax    
    mov     esi, eax
    
store_program_loop:
    push    edi
    call    _fgetc
    add     esp, 4
    
    cmp     eax, EOF                            ; stop reading when end of file reached
    jz      short store_program_done
    
    mov     [esi], al
    
    inc     esi
    jmp     short store_program_loop
    
store_program_done:
    mov     [esi], byte BF_PROGRAM_END          ; store program end special code
;
; close file
;
    push    edi
    call    _fclose
    add     esp, 4
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
    
    mov     [esi], al
    
    jmp     run_program_loop_end
    
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
    
error_exit_noargument:
    push    write_mode
    push    2
    call    _fdopen
    add     esp, 8

    push    error_noargument
    push    eax
    call    _fprintf
    add     esp, 8
    mov     eax, -1
    
    jmp     short exit
    
error_exit_notexist:
    push    write_mode
    push    2
    call    _fdopen
    add     esp, 8

    push    error_notexist
    push    eax
    call    _fprintf
    add     esp, 8
    mov     eax, -2
    
    jmp     short exit
    
error_exit_outofmemory:
    push    write_mode
    push    2
    call    _fdopen
    add     esp, 8

    push    error_outofmemory
    push    eax
    call    _fprintf
    add     esp, 8
    mov     eax, -3
    
    jmp     short exit
    
normal_exit:
    mov     eax, 0
    
exit:
    ret
    