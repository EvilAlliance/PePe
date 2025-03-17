const std = @import("std");

const Lexer = @import("../Lexer/Lexer.zig");
const TokenType = Lexer.TokenType;
const Token = Lexer.Token;
const Location = Lexer.Location;

expected: TokenType,
found: TokenType,
path: []const u8,
absPath: []const u8,
loc: Location,

pub fn display(self: @This()) void {
    std.log.err("Expected: {},\nFound: {},\nIn:{s}:{}:{}\n", .{
        self.expected,
        self.found,
        self.path,
        self.loc.row,
        self.loc.col,
    });
    self.loc.print(std.log.err);
}
