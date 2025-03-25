const std = @import("std");

const Parser = @import("../Parser/Parser.zig");
const Expression = Parser.Expression;

expr: *Expression,

pub fn init(expr: *Parser.Expression) @This() {
    return @This(){
        .expr = expr,
    };
}

pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) std.mem.Allocator.Error!void {
    for (0..d) |_|
        try cont.append(' ');

    try cont.appendSlice("return ");

    try self.expr.toString(cont, d);

    try cont.append('\n');
}
