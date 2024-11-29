const std = @import("std");
const util = @import("Util.zig");
const Lexer = @import("Lexer.zig");
const ParseArguments = @import("ParseArgs.zig");

const usage = @import("General.zig").usage;
const message = @import("General.zig").message;

const Result = util.Result;

const getArguments = ParseArguments.getArguments;
const Arguments = ParseArguments.Arguments;
const lex = Lexer.lex;
const Parser = @import("Parser.zig");

fn writeAll(c: []const u8, arg: Arguments, absPath: []const u8, extName: []const u8) std.fs.File.WriteError!void {
    var file: ?std.fs.File = null;
    defer {
        if (file) |f| f.close();
    }

    var writer: std.fs.File.Writer = undefined;

    if (arg.stdout) {
        writer = std.io.getStdOut().writer();
    } else {
        const fileName = std.mem.lastIndexOf(u8, absPath, "/").?;
        const ext = std.mem.lastIndexOf(u8, absPath, ".").?;
        var buf: [5120]u8 = undefined;
        const name = std.fmt.bufPrint(&buf, "{s}.{s}", .{ absPath[fileName + 1 .. ext], extName }) catch {
            std.debug.print("{s} Name is to large\n", .{message.Error});
            return;
        };

        file = std.fs.cwd().createFile(name, .{}) catch |err| {
            std.debug.print("{s} Could not open file ({s}) becuase {}\n", .{ message.Error, arg.path, err });
            return;
        };

        writer = file.?.writer();
    }

    try writer.writeAll(c);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const arguments = getArguments(alloc) orelse return usage();

    _ = arena.reset(std.heap.ArenaAllocator.ResetMode.retain_capacity);

    var lexer = lex(alloc, arguments) orelse return usage();

    if (arguments.lex) {
        const lexContent = lexer.toString(alloc) catch {
            std.debug.print("{s} Out of memory", .{message.Error});
            return;
        };

        try writeAll(lexContent.items, arguments, lexer.absPath, "lex");

        return;
    }

    var parser = Parser.Parser.init(alloc, &lexer);
    const unexpected = parser.parse();
    if (unexpected) |err| {
        err.display();
        return;
    }

    if (arguments.parse) {
        const cont = parser.toString(alloc) catch {
            std.debug.print("{s} Out of memory", .{message.Error});
            return;
        };

        try writeAll(cont.items, arguments, lexer.absPath, "parse");

        return;
    }
}
