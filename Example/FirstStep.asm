format ELF64 executable 5
entry main
segment readable executable
main:
    mov rax, 60
    mov rdi, 1
    syscall
