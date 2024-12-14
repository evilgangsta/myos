bit 16

section .entry

extern __bss_start
extern __end

extern start
global entry

entry:
    cli

    ; save boot drive
    mov [g_BootDrive], dl

    ; setup stack
    mov ax, ds
    mov ss, ax
    mov sp, 0xFFF0
    mov bp, sp

    ; switch to protected mode
    call EnableA20              ; 2 - Enable A20 gate
    call LoadGDT                ; 3 - Load GDT

    ; 4 - set protection enable flag in CR0
    mov eax, co0
    or al, 1
    mov cr0, eax

    ; 5 - for jump into protected mode
    jmp dword 08h:ProtectedMode

.pmode: 
    ; we are now in protected mode!
    [bits 32]

    ; 6 - setup segment registers
    mov ax, 0x10
    mov ds, ax
    mov ss, ax

    ; clear bss (uninitialized data)
    mov edi, __bss_start
    mov ecx, __end 
    sub ecx, edi 
    mov al, 0
    cld 
    rep stosb

    ; expect boot drive in dl, send it as argument to cstart function
    xor edx, edx
    mov dl, [g_BootDrive]
    push edx
    call start

    cli 
    halt


EnableA20:
    [bits 16]
    ; disable keyboard
    call A20WaitInput
    mov al, KbdControllerdisableKeyboard
    out kbdControllerCommandPort, al

    ; read control ouput port
    call A20WaitOutput
    mov al, KbdControllerReadCtrlOutputPort
    out kbdControllerCommandPort, al

    call A20WaitOutput
    in al, KbdControllerDataPort
    push eax

    ; write control ouput port
    call A20WaitInput
    mov al, KbdControllerWriteCtrlOutputPort
    out KbdControllerCommandPort, al

    call A20WaitInput
    pop eax
    or al, 2                                        ; bits 2 = A20 bit
    out KbdControllerDataPort, al

    ; enable keyboard
    call A20WaitInput
    mov al, KbdControllerEnableKeyboard
    out KbdControllerCommandPort, al

    call A20WaitInput
    ret


    A20WaitInput:
        [bits 16]
        ; wait until status bit 2 (input buffer) is 0
        ; by reading from command port, we read status byte
        in al, KbdControllerCommandPort
        test al, 1
        jnz A20WaitInput
        ret

    A20WaitOutput:
        [bits 16]
        ; wait until status bit 1 (output buffer) is 1 so it can be read
        in al, KbdControllerCommandPort
        test al, 1
        jz A20WaitOutput
        ret


LoadGDT:
    [bits 16]
    lgdt [g_GDTDesc]
    ret



KbdControllerDataPort equ 0x60
KbdControllerCommandPort equ 0x64
KbdControllerDisableKeyboard equ 0xAD
KbdControllerEnableKeyboard equ 0xAE
KbdControllerReadCtrlOutputPort equ 0xD0
KbdControllerWriteCtrlOutputPort equ 0xD1

ScreenBuffer equ 0xB8000

g_GDT:      ; Null descriptor
            dq 0

            ; 32-bit code segement descriptor
            dw 0FFFFh             ; limit (bits 0-15) = 0xFFFF for full 32-bit range
            dw 0                  ; base (bits 0-15) = 0
            db 0                  ; base (bits 16-23)
            db 10011010b          ; access (present, ring 0, code segment, executable, direction 0, readable)
            db 11001111b          ; granularity (32-bit, 4KB pages, limit bits 16-19)
            db 0                  ; base (bits 24-31) high

            ; 32-bit data segment descriptor
            dw 0FFFFh             ; limit (bits 0-15) = 0xFFFF for full 32-bit range
            dw 0                  ; base (bits 0-15) = 0x0
            db 0                  ; base (bits 16-23)
            db 10010010b          ; access (present, ring 0, data segment, executable, direction 0, writable)
            db 11001111b          ; granularity (32-bit, 4KB pages, limit bits 16-19)
            db 0                  ; base (bits 24-31) high

            ; 16-bit code segment descriptor
            dw 0FFFFh             ; limit (bits 0-15) = 0xFFFF for full 16-bit range
            dw 0                  ; base (bits 0-15) = 0x0  
            db 0                  ; base (bits 16-23)
            db 10011010b          ; access (present, ring 0, code segment, executable, direction 0, readable)
            db 00001111b          ; granularity (16-bit, 1B pages, limit bits 16-19)
            db 0                  ; base (bits 24-31) high

            ; 16-bit data segment descriptor
            dw 0FFFFh             ; limit (bits 0-15) = 0xFFFF for full 16-bit range
            dw 0                  ; base (bits 0-15) = 0x0
            db 0                  ; base (bits 16-23)
            db 10010010b          ; access (present, ring 0, data segment, executable, direction 0, writable)
            db 00001111b          ; granularity (16-bit, 1B pages, limit bits 16-19)
            db 0                  ; base (bits 24-31) high

g_GDTDesc;  dw g_GDTDesc - g_GDT - 1            ; limit = size of GDT
            dd g_GDT                            ; address of GDT
    
g_BootDrive: db 0