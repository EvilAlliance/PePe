const std = @import("std");
const util = @import("Util.zig");
const Lexer = @import("Lexer.zig");
const ParseArguments = @import("ParseArgs.zig");
const typeCheck = @import("TypeCheck.zig").typeCheck;

const usage = @import("General.zig").usage;

const Result = util.Result;

const getArguments = ParseArguments.getArguments;
const Arguments = ParseArguments.Arguments;
const lex = Lexer.lex;
const Parser = @import("Parser.zig");
const IR = @import("IR.zig").IR;

var silence = false;

pub const std_options = .{
    .logFn = log,
};

fn log(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (silence and message_level != .err) return;
    const level_txt = comptime switch (message_level) {
        .info => "[INFO]",
        .warn => "[WARNING]",
        .err => "[ERROR]",
        .debug => "[DEBUG]",
    };

    const prefix2 = if (scope == .default) " " else "(" ++ @tagName(scope) ++ "): ";
    const stderr = std.io.getStdErr().writer();
    var bw = std.io.bufferedWriter(stderr);
    const writer = bw.writer();

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    nosuspend {
        writer.print(level_txt ++ prefix2 ++ format ++ "\n", args) catch return;
        bw.flush() catch return;
    }
}

fn getName(alloc: std.mem.Allocator, absPath: []const u8, extName: []const u8) []u8 {
    const fileName = std.mem.lastIndexOf(u8, absPath, "/").?;
    const ext = std.mem.lastIndexOf(u8, absPath, ".").?;
    const name = std.fmt.allocPrint(alloc, "{s}.{s}", .{ absPath[fileName + 1 .. ext], extName }) catch {
        std.log.err("Name is to large\n", .{});
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
            std.log.err("Could not open file ({s}) becuase {}\n", .{ arg.path, err });
            return;
        };

        writer = file.?.writer();
    }

    writer.writeAll(c) catch |err| {
        std.log.err("Could not write to file ({s}) becuase {}\n", .{ arg.path, err });
        return;
    };
}

pub fn main() !u8 {
    var timer = std.time.Timer.start() catch unreachable;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const arguments = getArguments(alloc) orelse {
        usage();
        return 1;
    };

    silence = arguments.silence;

    _ = arena.reset(std.heap.ArenaAllocator.ResetMode.retain_capacity);

    std.log.info("Lexing and Parsing", .{});
    var lexer = lex(alloc, arguments) orelse {
        usage();
        return 1;
    };

    if (arguments.lex) {
        const lexContent = lexer.toString(alloc) catch {
            std.log.err("Out of memory", .{});
            return 1;
        };

        const name = getName(alloc, lexer.absPath, "lex");
        writeAll(lexContent.items, arguments, name);

        return 0;
    }

    var parser = Parser.Parser.init(alloc, &lexer);
    const unexpected = parser.parse() catch {
        std.log.err("Out of memory", .{});
        return 1;
    };

    if (unexpected) |err| {
        err.display();
        return 1;
    }

    if (arguments.bench)
        std.log.info("Finished in {}", .{std.fmt.fmtDuration(timer.lap())});

    if (arguments.parse) {
        const cont = parser.toString(alloc) catch {
            std.log.err("Out of memory", .{});
            return 1;
        };

        const name = getName(alloc, lexer.absPath, "parse");
        writeAll(cont.items, arguments, name);

        return 0;
    }

    std.log.info("Type Checking", .{});

    if (typeCheck(parser.program, alloc) catch {
        std.log.err("out of memory", .{});
        return 1;
    }) return 1;

    if (arguments.bench)
        std.log.info("Finished in {}", .{std.fmt.fmtDuration(timer.lap())});

    std.log.info("Intermediate Represetation", .{});
    var ir = IR.init(&parser.program, alloc);

    ir.toIR() catch {
        std.log.err("out of memory", .{});
        return 1;
    };

    if (arguments.bench)
        std.log.info("Finished in {}", .{std.fmt.fmtDuration(timer.lap())});

    if (arguments.ir) {
        const cont = ir.toString(alloc) catch {
            std.log.err("Out of memory", .{});
            return 1;
        };

        const name = getName(alloc, lexer.absPath, "ir");
        writeAll(cont.items, arguments, name);

        return 0;
    }

    return 0;
}
