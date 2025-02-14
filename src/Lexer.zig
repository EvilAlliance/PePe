const std = @import("std");
const util = @import("Util.zig");

const Arguments = @import("ParseArgs.zig").Arguments;

const Allocator = std.mem.Allocator;
const print = std.debug.print;
const assert = std.debug.assert;

pub const Location = struct {
    row: u64,
    col: u64,
};

pub const TokenType = enum {
    openParen,
    closeParen,
    openBrace,
    closeBrace,
    semicolon,
    ret,
    func,
    any,
    numberLiteral,
    iden,
    EOF,

    pub fn isIden(str: []const u8) bool {
        assert(str.len > 0);
        if (('A' > str[0] or str[0] > 'Z') and
            ('a' > str[0] or str[0] > 'z')) return false;

        return true;
    }

    pub fn isNumber(str: []const u8) bool {
        assert(str.len > 0);
        for (str) |c| {
            if ('0' > c or c > '9') return false;
        }

        return true;
    }

    pub fn get(str: []const u8) TokenType {
        if (str.len == 0) return TokenType.EOF;
        if (str.len == 1) {
            switch (str[0]) {
                '(' => return TokenType.openParen,
                ')' => return TokenType.closeParen,
                '{' => return TokenType.openBrace,
                '}' => return TokenType.closeBrace,
                ';' => return TokenType.semicolon,
                '0'...'9' => return TokenType.numberLiteral,
                'a'...'z', 'A'...'Z' => return TokenType.iden,
                else => return TokenType.any,
            }
        } else if (std.mem.eql(u8, str, "return")) {
            return TokenType.ret;
        } else if (std.mem.eql(u8, str, "fn")) {
            return TokenType.func;
        } else if (isIden(str)) {
            return TokenType.iden;
        } else if (isNumber(str)) {
            return TokenType.numberLiteral;
        } else {
            return TokenType.any;
        }
    }
};

pub const Token = struct {
    path: []const u8,
    absPath: []const u8,
    str: []const u8,
    type: TokenType,
    loc: Location,

    pub fn init(path: []const u8, absPath: []const u8, str: []const u8, loc: Location) Token {
        return Token{
            .path = path,
            .absPath = absPath,
            .type = TokenType.get(str),
            .str = str,
            .loc = loc,
        };
    }

    pub fn toString(self: @This(), alloc: Allocator, cont: *std.ArrayList(u8)) error{OutOfMemory}!void {
        try cont.appendSlice(self.path);
        try cont.append(':');

        const row = try std.fmt.allocPrint(alloc, "{}", .{self.loc.row});

        try cont.appendSlice(row);
        try cont.append(':');

        const col = try std.fmt.allocPrint(alloc, "{}", .{self.loc.col});

        try cont.appendSlice(col);
        try cont.append(' ');

        try cont.appendSlice(self.str);
        try cont.appendSlice(" (");

        try cont.appendSlice(@tagName(self.type));
        try cont.appendSlice(")\n");
    }
};

pub const Lexer = struct {
    path: []const u8,
    absPath: []const u8,
    content: []const u8,
    prevLoc: Location = Location{ .row = 1, .col = 1 },
    currentLoc: Location = Location{ .row = 1, .col = 1 },
    index: usize = 0,
    peeked: usize = 0,
    finished: bool = false,

    const separatorIgnore = " \t\n\r";
    const separator = separatorIgnore ++ "{}();";

    fn skipIgnore(self: *Lexer) void {
        while (self.index < self.content.len and util.listContains(u8, separatorIgnore, self.content[self.index])) {
            if (self.content[self.index] == '\n') {
                self.currentLoc.row += 1;
                self.currentLoc.col = 0;
            }
            self.index += 1;
            self.currentLoc.col += 1;
        }
    }

    pub fn advance(self: *Lexer) ?usize {
        if (self.index >= self.content.len - 1) return null;
        if (self.index < self.peeked) return self.peeked;

        self.skipIgnore();
        self.prevLoc = self.currentLoc;
        var i = self.index;

        while (i < self.content.len and !util.listContains(u8, separator, self.content[i])) {
            i += 1;
            self.currentLoc.col += 1;
        }

        if (self.index == i) {
            i += 1;
            self.currentLoc.col += 1;
        }

        return i;
    }

    pub fn peek(self: *Lexer) Token {
        self.peeked = self.advance() orelse {
            if (self.finished) unreachable;
            return Token.init(self.path, self.absPath, "", self.currentLoc);
        };

        return Token.init(self.path, self.absPath, self.content[self.index..self.peeked], self.prevLoc);
    }

    pub fn pop(self: *Lexer) Token {
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

    pub fn toString(self: *Lexer, alloc: std.mem.Allocator) error{OutOfMemory}!std.ArrayList(u8) {
        var cont = std.ArrayList(u8).init(alloc);

        var t = self.pop();
        while (!self.finished) : (t = self.pop()) {
            try t.toString(alloc, &cont);
        }

        try t.toString(alloc, &cont);

        return cont;
    }

    pub fn init(alloc: Allocator, path: []const u8) LexerCreationError!Lexer {
        const abspath = std.fs.realpathAlloc(alloc, path) catch return error.couldNotGetAbsolutePath;
        const f = std.fs.openFileAbsolute(abspath, .{ .mode = .read_only }) catch return error.couldNotOpenFile;
        defer f.close();
        const file_size = f.getEndPos() catch return error.couldNotGetFileSize;
        const max_bytes: usize = @intCast(file_size);
        const c = f.readToEndAlloc(alloc, max_bytes) catch return error.couldNotReadFile;

        return Lexer{
            .content = c,
            .absPath = abspath,
            .path = path,
        };
    }
};

pub fn lex(alloc: Allocator, arguments: Arguments) ?Lexer {
    const lexer = Lexer.init(alloc, arguments.path) catch |err| {
        switch (err) {
            error.couldNotOpenFile => std.log.err("Could not open file: {s}\n", .{arguments.path}),
            error.couldNotReadFile => std.log.err("Could not read file: {s}]n", .{arguments.path}),
            error.couldNotGetFileSize => std.log.err("Could not get file ({s}) size\n", .{arguments.path}),
            error.couldNotGetAbsolutePath => std.log.err("Could not get absolute path of file ({s})\n", .{arguments.path}),
        }
        return null;
    };

    return lexer;
}

const LexerCreationError = error{
    couldNotOpenFile,
    couldNotGetFileSize,
    couldNotReadFile,
    couldNotGetAbsolutePath,
};
