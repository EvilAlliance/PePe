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
content: [:0]const u8,
index: usize = 0,
loc: Location,
peeked: ?Token = null,
finished: bool = false,

alloc: Allocator,

const Status = enum {
    start,
    identifier,
    numberLiteral,
};

fn advanceIndex(self: *@This()) void {
    if (self.content.len == 0 or self.index >= self.content.len) unreachable;

    self.index += 1;
    self.loc.col += 1;
}

fn advance(self: *@This()) Token {
    if (self.finished) @panic("This function shouldnt be called if this has finished lexing");
    var t = Token.init(undefined, self.loc.shallowCopy(self.index, undefined));

    state: switch (Status.start) {
        .start => switch (self.content[self.index]) {
            0 => {
                t.tag = .EOF;
                self.finished = true;
            },
            '\n' => {
                self.advanceIndex();
                self.loc.col = 1;
                self.loc.row += 1;

                t.loc.start = self.index;
                t.loc.col = self.loc.col;
                t.loc.row = self.loc.row;
                continue :state .start;
            },
            '\t', '\r', ' ' => {
                self.advanceIndex();

                t.loc.start = self.index;
                t.loc.col = self.loc.col;
                t.loc.row = self.loc.row;
                continue :state .start;
            },

            'a'...'z', 'A'...'Z', '_' => {
                t.tag = .iden;
                continue :state .identifier;
            },
            '(' => {
                self.advanceIndex();
                t.tag = .openParen;
            },
            ')' => {
                self.advanceIndex();
                t.tag = .closeParen;
            },
            '{' => {
                self.advanceIndex();
                t.tag = .openBrace;
            },
            '}' => {
                self.advanceIndex();
                t.tag = .closeBrace;
            },
            '0'...'9' => {
                t.tag = .numberLiteral;
                continue :state .numberLiteral;
            },
            ';' => {
                self.advanceIndex();
                t.tag = .semicolon;
            },
            '+' => {
                self.advanceIndex();
                t.tag = .plus;
            },
            '-' => {
                self.advanceIndex();
                t.tag = .minus;
            },
            '*' => {
                self.advanceIndex();
                t.tag = .asterik;
            },
            '/' => {
                self.advanceIndex();
                t.tag = .slash;
            },
            else => {
                Logger.log.info("Found {s}", .{self.content[self.index .. self.index + 1]});
                unreachable;
            },
        },
        .identifier => {
            self.advanceIndex();
            switch (self.content[self.index]) {
                'a'...'z', 'A'...'Z', '_', '0'...'9' => continue :state .identifier,
                else => {
                    if (Token.getKeyWord(self.content[t.loc.start..self.index])) |tag| {
                        t.tag = tag;
                    }
                },
            }
        },
        .numberLiteral => {
            self.advanceIndex();
            switch (self.content[self.index]) {
                '0'...'9' => continue :state .numberLiteral,
                else => {},
            }
        },
    }

    t.loc.end = self.index;

    return t;
}

pub fn peek(self: *@This()) Token {
    if (self.peeked) |t| return t;
    self.peeked = self.advance();

    return self.peeked.?;
}

pub fn pop(self: *@This()) Token {
    if (self.peeked) |t| {
        self.peeked = null;
        return t;
    }

    return self.advance();
}

pub fn toString(self: *@This(), alloc: std.mem.Allocator) std.mem.Allocator.Error!std.ArrayList(u8) {
    var cont = std.ArrayList(u8).init(alloc);

    try cont.appendSlice(self.absPath);
    try cont.appendSlice(":\n");

    var t = self.pop();
    while (!self.finished) : (t = self.pop()) {
        try t.toString(alloc, &cont, self.path, self.content);
    }

    try t.toString(alloc, &cont, self.path, self.content);

    return cont;
}

pub fn init(alloc: Allocator, path: []const u8) LexerCreationError!@This() {
    const abspath = std.fs.realpathAlloc(alloc, path) catch return error.couldNotGetAbsolutePath;
    const f = std.fs.openFileAbsolute(abspath, .{ .mode = .read_only }) catch return error.couldNotOpenFile;
    defer f.close();
    const file_size = f.getEndPos() catch return error.couldNotGetFileSize;
    const max_bytes: usize = @intCast(file_size + 1);
    const c = f.readToEndAllocOptions(alloc, max_bytes, max_bytes, 1, 0) catch return error.couldNotReadFile;

    const l = @This(){
        .content = c,
        .absPath = abspath,
        .path = path,
        .alloc = alloc,
        .loc = Location.init(path, c),
    };

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
