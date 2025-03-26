const std = @import("std");

const Lexer = @import("./Lexer/Lexer.zig");

pub var silence = false;
pub var source: [:0]const u8 = .{};

pub const logLocation = struct {
    pub fn info(location: Lexer.Location, comptime format: []const u8, args: anytype) void {
        l(.info, location, format, args);
    }
    pub fn warn(location: Lexer.Location, comptime format: []const u8, args: anytype) void {
        l(.warn, location, format, args);
    }
    pub fn err(location: Lexer.Location, comptime format: []const u8, args: anytype) void {
        l(.err, location, format, args);
    }
    pub fn debug(location: Lexer.Location, comptime format: []const u8, args: anytype) void {
        l(.debug, location, format, args);
    }

    fn printPlace(location: Lexer.Location, writer: std.io.BufferedWriter(4096, std.fs.File.Writer).Writer) void {
        _ = location;
        _ = writer;
        unreachable;
    }

    fn l(comptime message_level: std.log.Level, location: Lexer.Location, comptime format: []const u8, args: anytype) void {
        if (silence and message_level != .err) return;
        const level_txt = comptime switch (message_level) {
            .info => "[INFO]",
            .warn => "[WARNING]",
            .err => "[ERROR]",
            .debug => "[DEBUG]",
        };

        const stderr = std.io.getStdErr().writer();
        var bw = std.io.bufferedWriter(stderr);
        const writer = bw.writer();

        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        nosuspend {
            writer.print("{s}:{}:{} ", .{ location.path, location.row, location.col }) catch return;
            writer.print(level_txt ++ ": " ++ format, args) catch return;
            printPlace(location, writer);
            bw.flush() catch return;
        }
    }
};

pub const log = struct {
    pub fn info(comptime format: []const u8, args: anytype) void {
        l(.info, format, args);
    }
    pub fn warn(comptime format: []const u8, args: anytype) void {
        l(.warn, format, args);
    }
    pub fn err(comptime format: []const u8, args: anytype) void {
        l(.err, format, args);
    }
    pub fn debug(comptime format: []const u8, args: anytype) void {
        l(.debug, format, args);
    }

    fn l(comptime message_level: std.log.Level, comptime format: []const u8, args: anytype) void {
        if (silence and message_level != .err) return;
        const level_txt = comptime switch (message_level) {
            .info => "[INFO]",
            .warn => "[WARNING]",
            .err => "[ERROR]",
            .debug => "[DEBUG]",
        };

        const stderr = std.io.getStdErr().writer();
        var bw = std.io.bufferedWriter(stderr);
        const writer = bw.writer();

        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        nosuspend {
            writer.print(level_txt ++ ": " ++ format ++ "\n", args) catch return;
            bw.flush() catch return;
        }
    }
};
