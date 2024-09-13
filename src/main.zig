const std = @import("std");

const usage = @import("General.zig").usage;
const message = @import("General.zig").message;

const Result = @import("Util.zig").Result;

const Argument = @import("ParseArgs.zig");

pub fn main() void {
    const allocator = std.heap.page_allocator;

    var args = std.ArrayList([]const u8).init(allocator);
    defer args.deinit();

    var argsIterator = std.process.ArgIterator.initWithAllocator(allocator) catch {
        std.debug.print("Out of memory", .{});
        return;
    };
    defer argsIterator.deinit();

    _ = argsIterator.skip();

    var arg = argsIterator.next();
    while (arg != null) : (arg = argsIterator.next()) {
        args.append(arg.?) catch {
            std.debug.print("Out of memory", .{});
            return;
        };
    }

    const a: Result(Argument.Arguments, Argument.ArgumentsError) = Argument.parseArguments(args.items);
    switch (a) {
        Result(Argument.Arguments, Argument.ArgumentsError).err => |err| {
            switch (err.err) {
                error.noSubcommandProvided => std.debug.print("{s} No subcommand provided\n", .{message.Error}),
                error.noFilePathProvided => std.debug.print("{s} No file provided\n", .{message.Error}),
                error.unknownSubcommand => std.debug.print("{s} Unknown subcommand {s}\n", .{ message.Error, err.arg.? }),
                error.unknownArgument => std.debug.print("{s} unknown argument {s}\n", .{ message.Error, err.arg.? }),
                else => unreachable,
            }
            usage();
            return;
        },
        Result(Argument.Arguments, Argument.ArgumentsError).ok => {},
    }

    const arguments = a.ok;
    std.debug.print("{}", .{arguments});
}
