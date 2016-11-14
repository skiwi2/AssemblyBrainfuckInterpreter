%include "asm_io.inc"

extern _malloc, _calloc

%define NEWLINE_CODE            10
%define BF_MEMORY_CELL_AMOUNT   30000

%define JUMP_PAST_CODE          91
%define JUMP_BACK_CODE          93

segment _DATA public align=4 class=DATA use32

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
                        times 128 dd bfprogram_invalidop

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
        global  _asm_main
_asm_main:
    enter   0,0                             ; setup routine
    pusha
;
; store Brainfuck program from console input
;    
    mov     eax, msg_memoryamount
    call    print_string
    
    call    read_int
    mov     [max_bf_program_size], eax
    
    push    eax
    call    _malloc
    add     esp, 4                          ; undo push
    
    test    eax, eax
    jz      error_exit_outofmemory
    
    mov     [bf_program], eax
    
    call    read_char                       ; consume newline
    
    mov     eax, msg_bfprogram
    call    print_string
    
    mov     ecx, [max_bf_program_size]
    xor     edx, edx
    
store_program_loop:
    call    read_char
    
    cmp     eax, NEWLINE_CODE               ; stop reading on newline
    jz      short store_program_done
    
    cmp     edx, ecx                        ; error if exceeded program size
    jz      error_exit_programsize
    
    mov     esi, [bf_program]
    mov     [esi + edx], al
    
    inc     edx
    jmp     short store_program_loop
    
store_program_done:
    mov     [bf_program_size], edx
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
    mov     esi, eax                        ; memory segment address
    mov     edi, [bf_program]               ; program address    
    mov     edx, 0                          ; program pointer offset
    mov     ecx, [bf_program_size]          ; actual program size
    mov     ebx, 0                          ; current memory cell offset
    
run_program_loop:        
    movzx   eax, byte [edi + edx]

    jmp     [bfprogram_jump_table + 4*eax]  ; addresses are dword, ASCII is translated to byte offsets

run_program_loop_end:
    inc     edx
    
    cmp     edx, ecx
    jz      short run_program_done
    
    jmp     short run_program_loop
    
run_program_done:
    jmp     normal_exit
    
bfprogram_pointer_right:
    inc     ebx
    
    jmp     run_program_loop_end
    
bfprogram_pointer_left:
    dec     ebx
    
    jmp     run_program_loop_end
    
bfprogram_memory_inc:
    mov     al, [esi + ebx]
    inc     al
    mov     [esi + ebx], al
    
    jmp     run_program_loop_end
    
bfprogram_memory_dec:
    mov     al, [esi + ebx]
    dec     al
    mov     [esi + ebx], al
    
    jmp     run_program_loop_end
    
bfprogram_output:
    mov     al, [esi + ebx]
    
    push    eax                             ; safe to do because eax is 000000xxh before the prior mov
    call    print_char
    add     esp, 4
    
    jmp     run_program_loop_end
    
bfprogram_input:
    call    read_char
    
    mov     [esi + ebx], al
    
    jmp     run_program_loop_end
    
bfprogram_jump_past:
    mov     al, [esi + ebx]
    
    test    al, al                          ; check if memory cell is zero
    jnz     run_program_loop_end            ; if not zero, move to next instruction
;
; find matching ]
;
; TODO use another 32-bit register once it's available after planned refactoring
    mov     ah, 1                          ; when counter reaches zero the ] is found where we need to jump past
    
bfprogram_jump_past_loop:
    inc     edx
    mov     al, [edi + edx]
    
    cmp     al, JUMP_PAST_CODE
    jz      short bfprogram_jump_past_loop_found_jump_past
    
    cmp     al, JUMP_BACK_CODE
    jz      short bfprogram_jump_past_loop_found_jump_back
    
    jmp     short bfprogram_jump_past_loop
    
bfprogram_jump_past_loop_found_jump_past:
    inc     ah
    
    jmp     short bfprogram_jump_past_loop
    
bfprogram_jump_past_loop_found_jump_back:
    dec     ah
    
    test    ah, ah
    jz      run_program_loop_end            ; jumped over matching ]
    
    jmp     short bfprogram_jump_past_loop
    
bfprogram_jump_back:
    mov     al, [esi + ebx]
    
    test    al, al                          ; check if memory cell is zero
    jz      run_program_loop_end            ; if zero, move to next instruction
;
; find matching [
;
; TODO use another 32-bit register once it's available after planned refactoring
    mov     ah, 1                           ; when counter reaches zero the [ is found where we need to jump back to
    
bfprogram_jump_back_loop:
    dec     edx
    mov     al, [edi + edx]
    
    cmp     al, JUMP_BACK_CODE
    jz      short bfprogram_jump_back_loop_found_jump_back
    
    cmp     al, JUMP_PAST_CODE
    jz      short bfprogram_jump_back_loop_found_jump_past
    
    jmp     short bfprogram_jump_back_loop
    
bfprogram_jump_back_loop_found_jump_back:
    inc     ah
    
    jmp     short bfprogram_jump_back_loop
    
bfprogram_jump_back_loop_found_jump_past:
    dec     ah
    
    test    ah, ah
    jz      run_program_loop_end            ; jumped back to matching [
    
    jmp     short bfprogram_jump_back_loop
    
bfprogram_invalidop:
    jmp     error_exit_invalidop
    
error_exit_outofmemory:
    mov     eax, error_outofmemory
    call    print_string                    ; TODO: this should really print to stderr
    popa
    mov     eax, -1
    jmp     short exit
    
error_exit_programsize:
    mov     eax, error_programsize
    call    print_string                    ; TODO: this should really print to stderr
    popa
    mov     eax, -2
    jmp     short exit
    
error_exit_invalidop:
    mov     eax, error_invalidop
    call    print_string                    ; TODO: this should really print to stderr
    popa
    mov     eax, -3
    jmp     short exit
    
normal_exit:
    popa
    mov     eax, 0
    
exit:
    leave
    ret
    