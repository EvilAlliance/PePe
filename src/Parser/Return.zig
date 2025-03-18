const std = @import("std");
const assert = std.debug.assert;

const Lexer = @import("../Lexer/Lexer.zig");
const Location = Lexer.Location;

const Expression = @import("./Expression.zig").Expression;

const Parser = @import("./Parser.zig");
const UnexpectedToken = Parser.UnexpectedToken;

pub const IR = @import("../IR/IR.zig");

const Util = @import("../Util.zig");
const Result = Util.Result;

expr: *Expression,
loc: Location,

pub fn parse(p: *Parser) Result(@This(), UnexpectedToken) {
    const r = Result(@This(), UnexpectedToken);

    const retToken = p.l.peek();
    assert(retToken.type == .ret);
    const retLoc = retToken.loc;

    _ = p.l.pop();

    const result = Expression.parse(p);
    switch (result) {
        .err => return r.Err(result.err),
        .ok => {},
    }
    const expr = result.ok;
    const ret = @This(){
        .expr = expr,
        .loc = retLoc,
    };

    const separator = p.l.pop();
    const unexpected = Parser.expect(separator, .semicolon);
    if (unexpected) |u| return r.Err(u);

    return r.Ok(ret);
}

pub fn toIR(self: @This()) IR.Return {
    return IR.Return.init(self.expr);
}

pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
    for (0..d) |_|
        try cont.append(' ');

    try cont.appendSlice("Return: ");
    try self.expr.toString(cont, d);
    try cont.append('\n');
}
