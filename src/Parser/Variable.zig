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

pub fn parse(p: *Parser) error{OutOfMemory}!Util.Result(@This(), UnexpectedToken) {
    const r = Util.Result(@This(), UnexpectedToken);

    const letToken = p.l.peek();
    assert(letToken.type == .let);
    _ = p.l.pop();

    const mutToken = p.l.peek();
    assert(mutToken.type == .mut);
    _ = p.l.pop();

    const name = p.l.peek();
    assert(name.type == .iden);
    _ = p.l.pop();

    const colon = p.l.peek();
    assert(colon.type == .symbol and colon.str.len == 1 and colon.str[0] == ':');
    _ = p.l.pop();

    const t = p.l.peek();
    assert(t.type == .iden);
    _ = p.l.pop();

    const equal = p.l.peek();
    assert(equal.type == .symbol and equal.str.len == 1 and equal.str[0] == '=');
    _ = p.l.pop();

    const expr = try Expression.parse(p);
    switch (expr) {
        .err => return r.Err(expr.err),
        .ok => {},
    }

    const semi = p.l.peek();
    assert(semi.type == .semicolon);
    _ = p.l.pop();

    return r.Ok(@This(){
        .mut = true,
        .name = name.str,
        .loc = letToken.loc,
        .t = Primitive.getType(t.str),
        .expr = expr.ok,
    });
}

pub fn toIR(self: @This()) IR.Variable {
    return IR.Variable.init(self);
}

pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
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
