:i argc 0
:b stdin 0

:i returncode 0
:b stdout 100
format ELF64 executable
segment readable executable
entry main
main:
mov rax, 60
mov rdi, 0
syscall

:b stderr 0

