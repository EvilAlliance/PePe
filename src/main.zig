const std = @import("std");
const util = @import("Util.zig");
const Lexer = @import("Lexer.zig");
const ParseArguments = @import("ParseArgs.zig");
const codeGen = @import("CodeGen.zig").codeGen;

const usage = @import("General.zig").usage;
const message = @import("General.zig").message;

const Result = util.Result;

const getArguments = ParseArguments.getArguments;
const Arguments = ParseArguments.Arguments;
const lex = Lexer.lex;
const Parser = @import("Parser.zig");
const IR = @import("IR.zig").IR;

fn getName(alloc: std.mem.Allocator, absPath: []const u8, extName: []const u8) []u8 {
    const fileName = std.mem.lastIndexOf(u8, absPath, "/").?;
    const ext = std.mem.lastIndexOf(u8, absPath, ".").?;
    const name = std.fmt.allocPrint(alloc, "{s}.{s}", .{ absPath[fileName + 1 .. ext], extName }) catch {
        std.debug.print("{s} Name is to large\n", .{message.Error});
        return "";
    };

    return name;
}

fn writeAll(c: []const u8, arg: Arguments, name: []u8) void {
    var file: ?std.fs.File = null;
    defer {
        if (file) |f| f.close();
    }

    var writer: std.fs.File.Writer = undefined;

    if (arg.stdout) {
        writer = std.io.getStdOut().writer();
    } else {
        file = std.fs.cwd().createFile(name, .{}) catch |err| {
            std.debug.print("{s} Could not open file ({s}) becuase {}\n", .{ message.Error, arg.path, err });
            return;
        };

        writer = file.?.writer();
    }

    writer.writeAll(c) catch |err| {
        std.debug.print("{s} Could not write to file ({s}) becuase {}\n", .{ message.Error, arg.path, err });
        return;
    };
}

pub fn main() !u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const arguments = getArguments(alloc) orelse {
        usage();
        return 1;
    };

    _ = arena.reset(std.heap.ArenaAllocator.ResetMode.retain_capacity);

    var lexer = lex(alloc, arguments) orelse {
        usage();
        return 1;
    };

    if (arguments.lex) {
        const lexContent = lexer.toString(alloc) catch {
            std.debug.print("{s} Out of memory", .{message.Error});
            return 1;
        };

        const name = getName(alloc, lexer.absPath, "lex");
        writeAll(lexContent.items, arguments, name);

        return 0;
    }

    var parser = Parser.Parser.init(alloc, &lexer);
    const unexpected = parser.parse() catch {
        std.debug.print("{s} Out of memory", .{message.Error});
        return 1;
    };

    if (unexpected) |err| {
        err.display();
        return 1;
    }

    if (arguments.parse) {
        const cont = parser.toString(alloc) catch {
            std.debug.print("{s} Out of memory", .{message.Error});
            return 1;
        };

        const name = getName(alloc, lexer.absPath, "parse");
        writeAll(cont.items, arguments, name);

        return 0;
    }

    var ir = IR.init(&parser.program, alloc);

    ir.toIR() catch {
        std.debug.print("{s} Out of memory", .{message.Error});
        return 1;
    };

    if (arguments.ir) {
        const cont = ir.toString(alloc) catch {
            std.debug.print("{s} Out of memory", .{message.Error});
            return 1;
        };

        const name = getName(alloc, lexer.absPath, "ir");
        writeAll(cont.items, arguments, name);

        return 0;
    }

    return 0;
}
