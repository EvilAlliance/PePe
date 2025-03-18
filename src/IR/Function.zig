const std = @import("std");

const Parser = @import("../Parser/Parser.zig");
const Primitive = Parser.Primitive;
const Function = Parser.Function;

const IR = @import("IR.zig");
const Block = IR.Block;

const tb = @import("../libs/tb/tb.zig");
const tbHelper = @import("../TBHelper.zig");

name: []const u8,
//args: void,
body: std.ArrayList(Block),
returnType: Primitive,
func: tb.Function,
externSymbol: *tb.Symbol,
prototype: *tb.FunctionPrototype,

pub fn transformToSSA(alloc: std.mem.Allocator, sf: Function, m: tb.Module) error{OutOfMemory}!@This() {
    var f = @This(){
        .name = sf.name,
        .body = std.ArrayList(Block).init(alloc),
        .returnType = sf.returnType,
        .func = m.functionCreate(sf.name, tb.Linkage.PRIVATE),
        .externSymbol = m.externCreate(sf.name, tb.ExternalType.SO_LOCAL),
        .prototype = tbHelper.getPrototype(m, sf.returnType),
    };

    try Block.transformBodyToSSA(alloc, &f.body, sf.body);

    return f;
}

pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
    for (0..d) |_|
        try cont.append(' ');

    try cont.appendSlice("Function:\n");

    for (0..d + 2) |_|
        try cont.append(' ');

    try cont.appendSlice("Name: ");
    try cont.appendSlice(self.name);
    try cont.append('\n');

    for (0..d + 2) |_|
        try cont.append(' ');

    try cont.appendSlice("Return Type: ");
    try self.returnType.toString(cont);
    try cont.append('\n');

    for (0..d + 2) |_|
        try cont.append(' ');

    try cont.appendSlice("Blocks:\n");

    for (self.body.items) |block| {
        try block.toString(cont, d + 4);
    }
}
