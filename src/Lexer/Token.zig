const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const Util = @import("../Util.zig");

const Lexer = @import("Lexer.zig");
const Location = Lexer.Location;
const Token = Lexer.Token;

pub const TokenType = enum {
    //symbols delimeters
    openParen,
    closeParen,

    openBrace,
    closeBrace,

    semicolon,

    //keyword
    let,
    mut,
    ret,
    func,

    //Can be many things
    numberLiteral,
    iden,

    //Symbols
    plus,
    minus,
    asterik,
    slash,
    caret,

    EOF,

    pub fn getName(self: @This()) []const u8 {
        return switch (self) {
            .openParen => "(",
            .closeParen => ")",

            .openBrace => "{",
            .closeBrace => "}",

            .semicolon => ";",

            .let => "let",
            .mut => "mut",
            .ret => "return",
            .func => "fn",

            .numberLiteral => "number literal",
            .iden => "identifier",

            .plus => "+",
            .minus => "-",
            .asterik => "*",
            .slash => "/",
            .caret => "^",

            .EOF => "EOF",
        };
    }

    pub fn toSymbol(self: @This()) ?[]const u8 {
        return switch (self) {
            .openParen => "(",
            .closeParen => ")",

            .openBrace => "{",
            .closeBrace => "}",

            .semicolon => ";",

            .let => "let",
            .mut => "mut",
            .ret => "return",
            .func => "fn",

            .numberLiteral => null,
            .iden => null,

            .plus => "+",
            .minus => "-",
            .asterik => "*",
            .slash => "/",
            .caret => "^",

            .EOF => "EOF",
        };
    }
};

const keyword = std.StaticStringMap(TokenType).initComptime(.{
    .{ "let", .let },
    .{ "mut", .mut },
    .{ "return", .ret },
    .{ "fn", .func },
});

tag: TokenType,
loc: Location,

pub fn getKeyWord(w: []const u8) ?TokenType {
    return keyword.get(w);
}

pub fn init(tag: TokenType, loc: Location) Token {
    return Token{
        .tag = tag,
        .loc = loc,
    };
}

pub fn getText(self: @This(), source: []const u8) []const u8 {
    return self.tag.toSymbol() orelse self.loc.getText(source);
}

pub fn toString(self: @This(), alloc: Allocator, cont: *std.ArrayList(u8), path: []const u8, source: [:0]const u8) std.mem.Allocator.Error!void {
    try cont.appendSlice(path);
    try cont.append(':');

    const row = try std.fmt.allocPrint(alloc, "{}", .{self.loc.row});

    try cont.appendSlice(row);
    try cont.append(':');

    const col = try std.fmt.allocPrint(alloc, "{}", .{self.loc.col});

    try cont.appendSlice(col);
    try cont.append(' ');

    try cont.appendSlice(self.getText(source));

    try cont.appendSlice(" (");
    try cont.appendSlice(@tagName(self.tag));
    try cont.appendSlice(")\n");
}
