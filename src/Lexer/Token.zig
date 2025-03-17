const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const Lexer = @import("Lexer.zig");
const Location = Lexer.Location;
const Token = Lexer.Token;

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
    symbol,
    EOF,

    pub fn isIden(str: []const u8) bool {
        assert(str.len > 0);
        return '0' > str[0] or str[0] > '9';
    }

    pub fn isNumber(str: []const u8) bool {
        assert(str.len > 0);
        for (str) |c| {
            if ('0' > c or c > '9') return false;
        }

        return true;
    }

    pub fn isType(str: []const u8) bool {
        _ = str;
        return false;
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
                else => return TokenType.symbol,
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
