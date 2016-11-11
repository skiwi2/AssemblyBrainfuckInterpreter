%include "asm_io.inc"

extern _malloc

%define NEWLINE_CODE  10

segment _DATA public align=4 class=DATA use32

msg_memoryamount    db      "Enter how much memory (in bytes) does your Brainfuck program needs: ", 0
msg_bfprogram       db      "Enter your Brainfuck program (use Enter exclusively to continue): ", 0

segment _BSS public align=4 class=BSS use32

bf_program_size     resd 1
bf_program          resd 1    

group DGROUP _BSS _DATA

segment _TEXT public align=1 class=CODE use32
        global  _asm_main
_asm_main:
    enter   0,0             ; setup routine
    pusha
;
; read Brainfuck program from console input
;    
    mov     eax, msg_memoryamount
    call    print_string
    
    call    read_int
    mov     [bf_program_size], eax
    
    push    eax
    call    _malloc
    add     esp, 4                      ; undo push
    mov     [bf_program], eax
    
    call    read_char                   ; consume newline
    
    mov     eax, msg_bfprogram
    call    print_string
    
    mov     ecx, [bf_program_size]
    xor     edx, edx
    
read_program_loop:
    call    read_char
    
    cmp     eax, NEWLINE_CODE           ; stop reading on newline
    jz      short read_program_done
    
    mov     [bf_program + edx], eax
    
    inc     edx
    loop    read_program_loop
    
read_program_done:
    
    popa
    mov     eax, 0
    leave
    ret
    