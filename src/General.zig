const std = @import("std");

pub fn usage() void {
    std.debug.print(
        \\    Usage:
        \\    PePe <subcommand> <file> <...args> -- <...executable args>
        \\    Subcomands
        \\        com Compiles file
        \\        run Compiles file and runs the executable
        \\        sim Interpreter of the same language
        \\    Arguments
        \\        -b - Benchs the stages the compiler goes through
        \\        -s - No output from the compiler except errors
        \\
    , .{});
}

const Message = struct {
    Error: []const u8 = "    [ERROR]:",
    Warning: []const u8 = "    [WARNING]:",
    Info: []const u8 = "    [Info]:",
};

pub const message = Message{};
