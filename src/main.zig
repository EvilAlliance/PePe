const std = @import("std");

const usage = @import("General.zig").usage;
const message = @import("General.zig").message;

const util = @import("Util.zig");
const Result = util.Result;

const Argument = @import("ParseArgs.zig");
const Lexer = @import("Lexer.zig");

const errorWriteAllToken = error{
    whileWritingBuffer,
};
const WriteTokenError = util.ErrorPayLoad(errorWriteAllToken, std.fs.File.WriteError);

pub fn main() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    var args = std.ArrayList([]const u8).init(alloc);
    defer args.deinit();

    var argsIterator = std.process.ArgIterator.initWithAllocator(alloc) catch {
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

    _ = arena.reset(std.heap.ArenaAllocator.ResetMode.retain_capacity);

    const arguments = a.ok;

    var lexer = Lexer.init(alloc, arguments.path) catch |err| {
        switch (err) {
            error.couldNotOpenFile => std.debug.print("{s} Could not open file: {s}\n", .{ message.Error, arguments.path }),
            error.couldNotReadFile => std.debug.print("{s} Could not read file: {s}]n", .{ message.Error, arguments.path }),
            error.couldNotGetFileSize => std.debug.print("{s} Could not get file ({s}) size\n", .{ message.Error, arguments.path }),
            error.couldNotGetAbsolutePath => std.debug.print("{s} Could not get absolute path of file ({s})\n", .{ message.Error, arguments.path }),
        }
        usage();
        return;
    };

    if (arguments.lex) {
        const i = std.mem.lastIndexOf(u8, lexer.absPath, "/").?;
        var buf: [5120]u8 = undefined;
        const name = std.fmt.bufPrint(&buf, "{s}.lex", .{lexer.absPath[i + 1 ..]}) catch {
            std.debug.print("{s} Name is to large\n", .{message.Error});
            return;
        };

        var file: std.fs.File = undefined;
        defer file.close();

        var writer: std.fs.File.Writer = undefined;

        if (arguments.stdout) {
            writer = std.io.getStdOut().writer();
        } else {
            file = std.fs.cwd().createFile(name, .{}) catch |err| {
                std.debug.print("{s} Could not open file ({s}) becuase {}\n", .{ message.Error, arguments.path, err });
                return;
            };

            writer = file.writer();
        }

        const err = writeAllToken(&lexer, writer) orelse return;

        switch (err.err) {
            error.whileWritingBuffer => std.debug.print("{s} while writing into file ({s}) becuase {}\n", .{ message.Error, arguments.path, err.payload }),
        }
        return;
    }

    var t = lexer.next();

    while (t != null) : (t = lexer.next()) {
        t.?.display();
    }

    std.debug.print("{}\n", .{arguments});
}

fn writeAllToken(l: *Lexer.Lexer, writer: std.fs.File.Writer) ?WriteTokenError {
    var t = l.next();

    while (t != null) : (t = l.next()) {
        _ = writer.print("{s}:{}:{} {s} ({s})\n", .{
            t.?.path,
            t.?.loc.row,
            t.?.loc.col,
            t.?.str,
            @tagName(t.?.type),
        }) catch |err| return WriteTokenError.init(error.whileWritingBuffer, err);
    }
    return null;
}
