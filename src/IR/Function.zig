const std = @import("std");

const Parser = @import("../Parser/Parser.zig");
const Primitive = Parser.Primitive;
const Function = Parser.Function;

const IR = @import("IR.zig");
const Instruction = IR.Instruction;

const tb = @import("../libs/tb/tb.zig");
const tbHelper = @import("../TBHelper.zig");

name: []const u8,
//args: void,
body: std.ArrayList(Instruction),
returnType: Primitive,
func: tb.Function,
externSymbol: *tb.Symbol,
prototype: *tb.FunctionPrototype,

pub fn init(alloc: std.mem.Allocator, f: Parser.Function, m: tb.Module) @This() {
    return @This(){
        .name = f.name,
        .body = std.ArrayList(IR.Instruction).init(alloc),
        .returnType = f.returnType,
        .func = m.functionCreate(f.name, tb.Linkage.PRIVATE),
        .externSymbol = m.externCreate(f.name, tb.ExternalType.SO_LOCAL),
        .prototype = tbHelper.getPrototype(m, f.returnType),
    };
}

pub fn codeGen(self: @This(), m: tb.Module, funcWS: tb.Worklist) tb.Function {
    const textSection = m.getText();

    const func = self.func;
    const funcPrototype = self.prototype;

    const g = func.graphBuilderEnter(textSection, funcPrototype, funcWS);
    defer g.exit();

    for (self.body.items) |inst| {
        inst.codeGen(g, self);
    }

    return func;
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

    try cont.appendSlice("Body:\n");

    for (self.body.items) |inst| {
        try inst.toString(cont, d + 4);
    }
}
