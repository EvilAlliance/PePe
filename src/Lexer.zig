const std = @import("std");
const util = @import("Util.zig");

const Allocator = std.mem.Allocator;
const print = std.debug.print;
const assert = std.debug.assert;

const Location = struct {
    row: u64,
    col: u64,
};

const TokenType = enum {
    openParen,
    closeParen,
    openBrace,
    closeBrace,
    semicolon,
    ret,
    func,
    any,

    pub fn get(str: []const u8) TokenType {
        if (str.len == 1) {
            if (str[0] == '(') {
                return TokenType.openParen;
            } else if (str[0] == ')') {
                return TokenType.closeParen;
            } else if (str[0] == '{') {
                return TokenType.openBrace;
            } else if (str[0] == '}') {
                return TokenType.closeBrace;
            } else if (str[0] == ';') {
                return TokenType.semicolon;
            } else {
                return TokenType.any;
            }
        } else if (std.mem.eql(u8, str, "return")) {
            return TokenType.ret;
        } else if (std.mem.eql(u8, str, "fn")) {
            return TokenType.func;
        } else {
            return TokenType.any;
        }
    }
};

const Token = struct {
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

    pub fn display(self: *Token) void {
        print("{s}:{}:{} {s} ({s})\n", .{ self.path, self.loc.row, self.loc.col, self.str, @tagName(self.type) });
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

    pub fn peek(self: *Lexer) ?Token {
        self.peeked = self.advance() orelse null;

        return Token.init(self.path, self.absPath, self.content[self.index..self.peeked], self.prevLoc);
    }

    pub fn pop(self: *Lexer) ?Token {
        const i = self.advance() orelse return null;
        const t = Token.init(self.path, self.absPath, self.content[self.index..i], self.prevLoc);

        self.index = i;
        self.prevLoc = self.currentLoc;

        return t;
    }

    pub fn next(self: *Lexer) ?Token {
        const i = self.advance() orelse return null;
        const t = Token.init(self.path, self.absPath, self.content[self.index..i], self.prevLoc);

        self.index = i;

        self.prevLoc = self.currentLoc;

        return t;
    }
};

const LexerCreationError = error{
    couldNotOpenFile,
    couldNotGetFileSize,
    couldNotReadFile,
    couldNotGetAbsolutePath,
};

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
