const std = @import("std");
const util = @import("./../Util.zig");

const Logger = @import("../Logger.zig");

const Arguments = @import("./../ParseArgs.zig").Arguments;

pub const Location = @import("./Location.zig");
pub const Token = @import("./Token.zig");
pub const TokenType = Token.TokenType;

const Allocator = std.mem.Allocator;
const print = std.debug.print;
const assert = std.debug.assert;

const LexerCreationError = error{
    couldNotOpenFile,
    couldNotGetFileSize,
    couldNotReadFile,
    couldNotGetAbsolutePath,
};

path: []const u8,
absPath: []const u8,
content: []const u8,
prevLoc: Location = Location{ .row = 1, .col = 1, .i = 0, .path = "", .content = "" },
currentLoc: Location = Location{ .row = 1, .col = 1, .i = 0, .path = "", .content = "" },
index: usize = 0,
peeked: usize = 0,
finished: bool = false,

alloc: Allocator,

pub const separatorIgnore = " \t\n\r";
pub const separator = "(){};" ++ separatorIgnore;
// 127 - 33 count of printable caracters
// - (26 * 2) a-z A-Z
// - 10 numbres
// - 5 printable separator
// _ should be possible to use as an identifier
pub const symbols: [(127 - 33) - (26 * 2) - 10 - 5 - 1]u8 = blk: {
    var result: [(127 - 33) - (26 * 2) - 10 - 5 - 1]u8 = undefined;
    var index: usize = 0;

    for (33..127) |i| {
        const c: u8 = @intCast(i);
        if (!std.ascii.isAlphanumeric(c) and !util.listContains(u8, separator, i) and i != '_') {
            result[index] = c;
            index += 1;
        }
    }

    break :blk result;
};

fn skipIgnore(self: *@This()) void {
    while (self.index < self.content.len and util.listContains(u8, separatorIgnore, self.content[self.index])) {
        if (self.content[self.index] == '\n') {
            self.currentLoc.row += 1;
            self.currentLoc.col = 0;
        }
        self.index += 1;
        self.currentLoc.col += 1;
    }
    self.currentLoc.i = self.index;
}

pub fn advance(self: *@This()) ?usize {
    if (self.content.len == 0 or self.index >= self.content.len - 1) return null;
    if (self.index < self.peeked) return self.peeked;

    self.skipIgnore();
    self.prevLoc = self.currentLoc;
    var i = self.index;

    while (i < self.content.len and !util.listContains(u8, separator, self.content[i]) and !util.listContains(u8, &symbols, self.content[i])) {
        i += 1;
        self.currentLoc.col += 1;
    }

    if (self.index == i) {
        i += 1;
        self.currentLoc.col += 1;
    }
    self.currentLoc.i = self.index;

    return i;
}

pub fn peek(self: *@This()) Token {
    self.peeked = self.advance() orelse {
        if (self.finished) unreachable;
        return Token.init(self.path, self.absPath, "", self.currentLoc);
    };

    return Token.init(self.path, self.absPath, self.content[self.index..self.peeked], self.prevLoc);
}

pub fn pop(self: *@This()) Token {
    const i = self.advance() orelse {
        if (self.finished) unreachable;
        self.finished = true;
        return Token.init(self.path, self.absPath, "", self.currentLoc);
    };

    const t = Token.init(self.path, self.absPath, self.content[self.index..i], self.prevLoc);

    self.index = i;
    self.prevLoc = self.currentLoc;

    return t;
}

pub fn toString(self: *@This(), alloc: std.mem.Allocator) std.mem.Allocator.Error!std.ArrayList(u8) {
    var cont = std.ArrayList(u8).init(alloc);

    var t = self.pop();
    while (!self.finished) : (t = self.pop()) {
        try t.toString(alloc, &cont);
    }

    try t.toString(alloc, &cont);

    return cont;
}

pub fn init(alloc: Allocator, path: []const u8) LexerCreationError!@This() {
    const abspath = std.fs.realpathAlloc(alloc, path) catch return error.couldNotGetAbsolutePath;
    const f = std.fs.openFileAbsolute(abspath, .{ .mode = .read_only }) catch return error.couldNotOpenFile;
    defer f.close();
    const file_size = f.getEndPos() catch return error.couldNotGetFileSize;
    const max_bytes: usize = @intCast(file_size);
    const c = f.readToEndAlloc(alloc, max_bytes) catch return error.couldNotReadFile;

    var l = @This(){
        .content = c,
        .absPath = abspath,
        .path = path,
        .alloc = alloc,
    };

    l.prevLoc.path = path;
    l.prevLoc.content = c;
    l.currentLoc.path = path;
    l.currentLoc.content = c;

    return l;
}

pub fn deinit(self: @This()) void {
    self.alloc.free(self.content);
    self.alloc.free(self.absPath);
}

pub fn lex(alloc: Allocator, arguments: Arguments) ?@This() {
    const lexer = @This().init(alloc, arguments.path) catch |err| {
        switch (err) {
            error.couldNotOpenFile => Logger.log.err("Could not open file: {s}\n", .{arguments.path}),
            error.couldNotReadFile => Logger.log.err("Could not read file: {s}]n", .{arguments.path}),
            error.couldNotGetFileSize => Logger.log.err("Could not get file ({s}) size\n", .{arguments.path}),
            error.couldNotGetAbsolutePath => Logger.log.err("Could not get absolute path of file ({s})\n", .{arguments.path}),
        }
        return null;
    };

    return lexer;
}
