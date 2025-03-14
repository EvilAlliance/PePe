const std = @import("std");
const IR = @import("IR.zig");
const tb = @import("libs/tb/tb.zig");

const tbHelper = @import("TBHelper.zig");
const getDebugType = tbHelper.getDebugType;

const Intrinsic = @import("Intrinsics.zig").IntrinsicFn;

const c = @cImport({
    @cInclude("stdio.h");
});

const Primitive = @import("./Parser.zig").Primitive;

const SSA = IR.SSA;
const SSAFunction = IR.SSAFunction;
const SSAInstruction = IR.SSAInstruction;

const CodeGen = struct {};

pub fn codeGen(m: tb.Module, ir: SSA) error{OutOfMemory}!tb.Function {
    const ws = tb.Worklist.alloc();
    defer ws.free();

    const sectionText = m.getText();

    var funcIterator = ir.funcs.iterator();
    var func = funcIterator.next();

    while (func != null) : (func = funcIterator.next()) {
        _ = codeGenFunction(m, ws, func.?.value_ptr.*);
    }

    const startF = m.functionCreate("_start", tb.Linkage.PUBLIC);
    const startP = m.createPrototype(tb.CallingConv.STDCALL, 0, null, 0, null, false);

    {
        const g = startF.graphBuilderEnter(sectionText, startP, ws);
        defer g.exit();

        const irMain = ir.funcs.get("main").?;

        const mainExtern = irMain.externSymbol;
        const mainPrototype = irMain.prototype;

        const ret = g.call(mainPrototype, 0, g.symbol(mainExtern), 0, null);

        const exit = comptime Intrinsic.get("@exit").?;

        _ = exit(g, ret, 1);

        g.ret(0, 0, null);
    }

    return startF;
}

fn codeGenFunction(m: tb.Module, funcWS: tb.Worklist, f: SSAFunction) tb.Function {
    const textSection = m.getText();

    const func = f.func;
    const funcPrototype = f.prototype;

    _ = funcWS;
    const g = func.graphBuilderEnter(textSection, funcPrototype, null);
    defer g.exit();

    for (f.body.items) |block| {
        const insts: []SSAInstruction = block.body.items;
        for (insts) |inst| {
            codeGenInstruction(g, f, inst);
        }
    }

    return func;
}

fn codeGenInstruction(g: tb.GraphBuilder, f: SSAFunction, inst: SSAInstruction) void {
    switch (inst) {
        .ret => |ret| {
            std.log.warn("Only parsing expr of return value as unsigned and I assume there is a return of unsigned", .{});
            var node = ret.expr.codeGen(g, f);
            g.ret(0, 1, @ptrCast(&node));
        },
        .intrinsic => unreachable,
    }
}
