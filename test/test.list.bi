:i count 8
:b shell 9
zig build
:i returncode 0
:b stdout 0

:b stderr 0

:b shell 16
zig build run --
:i returncode 0
:b stdout 0

:b stderr 479
    [ERROR]: No subcommand provided
    Usage:
    PePe <subcommand> <file> <...args> -- <...executable args>
    Subcomands
        com Compiles file
        run Compiles file and runs the executable
        sim Interpreter of the same language
        lex Output the tokens of the file
    Arguments
        -b - Benchs the stages the compiler goes through
        -s - No output from the compiler except error
        -output - Insted of creating a file it prints the content

:b shell 20
zig build run -- com
:i returncode 0
:b stdout 0

:b stderr 473
    [ERROR]: No file provided
    Usage:
    PePe <subcommand> <file> <...args> -- <...executable args>
    Subcomands
        com Compiles file
        run Compiles file and runs the executable
        sim Interpreter of the same language
        lex Output the tokens of the file
    Arguments
        -b - Benchs the stages the compiler goes through
        -s - No output from the compiler except error
        -output - Insted of creating a file it prints the content

:b shell 20
zig build run -- run
:i returncode 0
:b stdout 0

:b stderr 473
    [ERROR]: No file provided
    Usage:
    PePe <subcommand> <file> <...args> -- <...executable args>
    Subcomands
        com Compiles file
        run Compiles file and runs the executable
        sim Interpreter of the same language
        lex Output the tokens of the file
    Arguments
        -b - Benchs the stages the compiler goes through
        -s - No output from the compiler except error
        -output - Insted of creating a file it prints the content

:b shell 30
zig build run -- com file-path
:i returncode 0
:b stdout 0

:b stderr 479
    [ERROR]: Unknown subcommand com
    Usage:
    PePe <subcommand> <file> <...args> -- <...executable args>
    Subcomands
        com Compiles file
        run Compiles file and runs the executable
        sim Interpreter of the same language
        lex Output the tokens of the file
    Arguments
        -b - Benchs the stages the compiler goes through
        -s - No output from the compiler except error
        -output - Insted of creating a file it prints the content

:b shell 33
zig build run -- run file-path -f
:i returncode 0
:b stdout 0

:b stderr 476
    [ERROR]: unknown argument -f
    Usage:
    PePe <subcommand> <file> <...args> -- <...executable args>
    Subcomands
        com Compiles file
        run Compiles file and runs the executable
        sim Interpreter of the same language
        lex Output the tokens of the file
    Arguments
        -b - Benchs the stages the compiler goes through
        -s - No output from the compiler except error
        -output - Insted of creating a file it prints the content

:b shell 28
zig test ./src/ParseArgs.zig
:i returncode 0
:b stdout 0

:b stderr 98
1/3 ParseArgs.test_0...OK
2/3 ParseArgs.test_1...OK
3/3 ParseArgs.test_2...OK
All 3 tests passed.

:b shell 47
zig build run -- lex ./Example/Basic.pp -stdout
:i returncode 0
:b stdout 357
./Example/Basic.pp:1:1 fn (func)
./Example/Basic.pp:1:4 main (any)
./Example/Basic.pp:1:8 ( (openParen)
./Example/Basic.pp:1:9 ) (closeParen)
./Example/Basic.pp:1:11 u8 (any)
./Example/Basic.pp:1:13 { (openBrace)
./Example/Basic.pp:2:5 return (ret)
./Example/Basic.pp:2:12 0 (any)
./Example/Basic.pp:2:13 ; (semicolon)
./Example/Basic.pp:3:1 } (closeBrace)

:b stderr 0

