const std = @import("std");

const Parser = @import("../Parser/Parser.zig");
const Statements = Parser.Statements;
const Statement = Parser.Statement;
const Expression = Parser.Expression;
const Primitive = Parser.Primitive;

pub const Intrinsic = @import("./Intrinsic.zig");
pub const Return = @import("./Return.zig");
pub const Instruction = @import("./Instruction.zig").Instruction;
pub const Function = @import("./Function.zig");
pub const Program = @import("./Program.zig");

const tb = @import("../libs/tb/tb.zig");
const tbHelper = @import("../TBHelper.zig");

program: *Parser.Program,
ir: Program,
alloc: std.mem.Allocator,

pub fn init(p: *Parser.Program, alloc: std.mem.Allocator) @This() {
    return @This(){
        .alloc = alloc,
        .program = p,
        .ir = Program.init(alloc),
    };
}

pub fn deinit(self: *@This()) void {
    self.ir.deinit();
}

pub fn toIR(self: *@This(), m: tb.Module) error{OutOfMemory}!void {
    var it = self.program.funcs.iterator();
    while (it.next()) |c| {
        const func = c.value_ptr.*;
        const f = try func.toIR(self.alloc, &self.ir, m);

        try self.ir.funcs.put(f.name, f);
    }
}

pub fn codeGen(self: *@This(), m: tb.Module) error{OutOfMemory}!tb.Function {
    const ws = tb.Worklist.alloc();
    defer ws.free();

    const sectionText = m.getText();

    var funcIterator = self.ir.funcs.valueIterator();

    while (funcIterator.next()) |func| {
        _ = func.codeGen(m, ws);
    }

    const startF = m.functionCreate("_start", tb.Linkage.PUBLIC);
    const startP = m.createPrototype(tb.CallingConv.STDCALL, 0, null, 0, null, false);

    {
        const g = startF.graphBuilderEnter(sectionText, startP, ws);
        defer g.exit();

        const irMain = self.ir.funcs.get("main").?;

        const mainExtern = irMain.externSymbol;
        const mainPrototype = irMain.prototype;

        const ret = g.call(mainPrototype, 0, g.symbol(mainExtern), 0, null);

        const exit = comptime Intrinsic.Function.get("@exit").?;

        _ = exit(g, ret, 1);

        g.ret(0, 0, null);
    }

    return startF;
}

pub fn toString(self: *@This(), alloc: std.mem.Allocator) error{OutOfMemory}!std.ArrayList(u8) {
    var cont = std.ArrayList(u8).init(alloc);

    try self.ir.toString(&cont);

    return cont;
}
