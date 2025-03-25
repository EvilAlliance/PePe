const std = @import("std");
const assert = std.debug.assert;

const Parser = @import("./Parser.zig");
const Expression = Parser.Expression;
const Primitive = Parser.Primitive;
const UnexpectedToken = Parser.UnexpectedToken;

const Lexer = @import("./../Lexer/Lexer.zig");

pub const IR = @import("../IR/IR.zig");

const Util = @import("./../Util.zig");

mut: bool,

name: []const u8,
loc: Lexer.Location,

t: Primitive,
expr: *Expression,

pub fn parse(p: *Parser) (std.mem.Allocator.Error || error{UnexpectedToken})!@This() {
    const letToken = p.l.peek();
    assert(letToken.type == .let);
    _ = p.l.pop();

    const mutToken = p.l.peek();
    if (!try p.expect(mutToken, &[_]Lexer.TokenType{.mut})) return error.UnexpectedToken;
    _ = p.l.pop();

    const name = p.l.peek();
    if (!try p.expect(name, &[_]Lexer.TokenType{.iden})) return error.UnexpectedToken;
    _ = p.l.pop();

    const colon = p.l.peek();
    if (!try p.expect(colon, &[_]Lexer.TokenType{.symbol})) return error.UnexpectedToken;
    assert(colon.type == .symbol and colon.str.len == 1 and colon.str[0] == ':');
    _ = p.l.pop();

    const t = p.l.peek();
    if (!try p.expect(t, &[_]Lexer.TokenType{.iden})) return error.UnexpectedToken;
    _ = p.l.pop();

    const equal = p.l.peek();
    if (!try p.expect(equal, &[_]Lexer.TokenType{.symbol})) return error.UnexpectedToken;
    assert(equal.type == .symbol and equal.str.len == 1 and equal.str[0] == '=');
    _ = p.l.pop();

    const expr = try Expression.parse(p);

    const semi = p.l.peek();
    if (!try p.expect(semi, &[_]Lexer.TokenType{.semicolon})) return error.UnexpectedToken;
    _ = p.l.pop();

    return @This(){
        .mut = true,
        .name = name.str,
        .loc = letToken.loc,
        .t = Primitive.getType(t.str),
        .expr = expr,
    };
}

pub fn toIR(self: @This()) IR.Variable {
    return IR.Variable.init(self);
}

pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) std.mem.Allocator.Error!void {
    for (0..d) |_|
        try cont.append(' ');

    try cont.appendSlice("Var: ");
    try cont.appendSlice(self.name);
    try cont.append(' ');
    try cont.appendSlice(if (self.mut) "mut" else "const");
    try cont.append(' ');
    try self.t.toString(cont);
    try cont.appendSlice(" = ");
    try self.expr.toString(cont, d);
    try cont.append('\n');
}
