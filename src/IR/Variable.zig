const std = @import("std");

const Parser = @import("./../Parser/Parser.zig");

const Lexer = @import("./../Lexer/Lexer.zig");

const tb = @import("../libs/tb/tb.zig");
const tbHelper = @import("../TBHelper.zig");

mut: bool,

name: []const u8,
loc: Lexer.Location,

t: Parser.Primitive,
expr: *Parser.Expression,

pub fn init(r: Parser.Variable) @This() {
    return @This(){
        .mut = r.mut,
        .name = r.name,
        .loc = r.loc,
        .t = r.t,
        .expr = r.expr,
    };
}

pub fn codeGen(self: @This(), g: tb.GraphBuilder, scope: *std.StringHashMap(*tb.Node)) *tb.Node {
    std.debug.assert(self.t.size % 8 == 0);
    const addr = g.local(self.t.size / 8, self.t.size / 8);

    g.store(0, false, addr, self.expr.codeGen(g, scope, self.t, tbHelper.getType(self.t)), self.t.size / 8, false);

    return addr;
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
