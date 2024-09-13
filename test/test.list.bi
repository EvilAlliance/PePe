:i count 7
:b shell 9
zig build
:i returncode 0
:b stdout 0

:b stderr 0

:b shell 16
zig build run --
:i returncode 0
:b stdout 0

:b stderr 372
    [ERROR]: No subcommand provided
    Usage:
    PePe <subcommand> <file> <...args> -- <...executable args>
    Subcomands
        com Compiles file
        run Compiles file and runs the executable
        sim Interpreter of the same language
    Arguments
        -b - Benchs the stages the compiler goes through
        -s - No output from the compiler except errors

:b shell 20
zig build run -- com
:i returncode 0
:b stdout 0

:b stderr 366
    [ERROR]: No file provided
    Usage:
    PePe <subcommand> <file> <...args> -- <...executable args>
    Subcomands
        com Compiles file
        run Compiles file and runs the executable
        sim Interpreter of the same language
    Arguments
        -b - Benchs the stages the compiler goes through
        -s - No output from the compiler except errors

:b shell 20
zig build run -- run
:i returncode 0
:b stdout 0

:b stderr 366
    [ERROR]: No file provided
    Usage:
    PePe <subcommand> <file> <...args> -- <...executable args>
    Subcomands
        com Compiles file
        run Compiles file and runs the executable
        sim Interpreter of the same language
    Arguments
        -b - Benchs the stages the compiler goes through
        -s - No output from the compiler except errors

:b shell 30
zig build run -- com file-path
:i returncode 0
:b stdout 0

:b stderr 372
    [ERROR]: Unknown subcommand com
    Usage:
    PePe <subcommand> <file> <...args> -- <...executable args>
    Subcomands
        com Compiles file
        run Compiles file and runs the executable
        sim Interpreter of the same language
    Arguments
        -b - Benchs the stages the compiler goes through
        -s - No output from the compiler except errors

:b shell 33
zig build run -- run file-path -f
:i returncode 0
:b stdout 0

:b stderr 369
    [ERROR]: unknown argument -f
    Usage:
    PePe <subcommand> <file> <...args> -- <...executable args>
    Subcomands
        com Compiles file
        run Compiles file and runs the executable
        sim Interpreter of the same language
    Arguments
        -b - Benchs the stages the compiler goes through
        -s - No output from the compiler except errors

:b shell 28
zig test ./src/ParseArgs.zig
:i returncode 0
:b stdout 0

:b stderr 98
1/3 ParseArgs.test_0...OK
2/3 ParseArgs.test_1...OK
3/3 ParseArgs.test_2...OK
All 3 tests passed.

