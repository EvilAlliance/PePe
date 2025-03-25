const std = @import("std");
const assert = std.debug.assert;

const Lexer = @import("../Lexer/Lexer.zig");
const Location = Lexer.Location;

const Expression = @import("./Expression.zig").Expression;

const Parser = @import("./Parser.zig");
const UnexpectedToken = Parser.UnexpectedToken;

pub const IR = @import("../IR/IR.zig");

const Util = @import("../Util.zig");

expr: *Expression,
loc: Location,

pub fn parse(p: *Parser) (std.mem.Allocator.Error || error{UnexpectedToken})!@This() {
    const retToken = p.l.peek();
    assert(retToken.type == .ret);
    const retLoc = retToken.loc;

    _ = p.l.pop();

    const expr = try Expression.parse(p);
    const ret = @This(){
        .expr = expr,
        .loc = retLoc,
    };

    const separator = p.l.pop();
    if (!try p.expect(separator, &[_]Lexer.TokenType{.semicolon})) return error.UnexpectedToken;

    return ret;
}

pub fn toIR(self: @This()) IR.Return {
    return IR.Return.init(self.expr);
}

pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) std.mem.Allocator.Error!void {
    for (0..d) |_|
        try cont.append(' ');

    try cont.appendSlice("Return: ");
    try self.expr.toString(cont, d);
    try cont.append('\n');
}
