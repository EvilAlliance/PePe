const std = @import("std");

pub fn usage() void {
    std.debug.print(
        \\    Usage:
        \\    PePe <subcommand> <file> <...args> -- <...executable args>
        \\    Subcomands
        \\        build Compiles file
        \\        run Compiles file and runs the executable
        \\        sim Interpreter of the same language
        \\        lex Output the tokens of the file
        \\        parse Output the AST of the file
        \\        ir Output the intermediate representation of the file
        \\    Arguments
        \\        -b - Benchs the stages the compiler goes through
        \\        -s - No output from the compiler except errors
        \\        -stdout - Insted of creating a file it prints the content
        \\
    , .{});
}
