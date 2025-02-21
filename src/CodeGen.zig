const std = @import("std");
const IR = @import("IR.zig");
const tb = @import("libs/tb/tb.zig");

const c = @cImport({
    @cInclude("stdio.h");
});

const Primitive = @import("./Parser.zig").Primitive;

const Allocator = std.mem.Allocator;
const SSA = IR.SSA;
const SSAFunction = IR.SSAFunction;
const SSAInstruction = IR.SSAInstruction;

const Commnad = @import("./Util.zig").Command;

const FunctionWs = struct {
    f: tb.Function,
    ws: tb.Worklist,
};

var externMap: ?std.StringHashMap(*tb.Symbol) = null;
var prototypeMap: ?std.StringHashMap(*tb.FunctionPrototype) = null;

fn getType(t: Primitive) tb.DataType {
    return switch (t.type) {
        .bool => tb.typeBool(),
        .float => switch (t.size) {
            32 => tb.typeF32(),
            64 => tb.typeF64(),
            else => unreachable,
        },
        .signed => switch (t.size) {
            8 => tb.typeI8(),
            16 => tb.typeI16(),
            32 => tb.typeI32(),
            64 => tb.typeI64(),
            else => unreachable,
        },
        .unsigned => switch (t.size) {
            8 => tb.typeI8(),
            16 => tb.typeI16(),
            32 => tb.typeI32(),
            64 => tb.typeI64(),
            else => unreachable,
        },
        .void => tb.typeVoid(),
    };
}
fn getDebugType(m: tb.Module, t: Primitive) ?*tb.DebugType {
    return switch (t.type) {
        .bool => m.debugGetBool(),
        .float => switch (t.size) {
            32 => m.debugGetFloat32(),
            64 => m.debugGetFloat64(),
            else => unreachable,
        },
        .signed => m.debugGetInteger(true, t.size),
        .unsigned => m.debugGetInteger(false, t.size),
        .void => m.debugGetVoid(),
    };
}

fn getPrototypeParam(m: tb.Module, t: Primitive) ?[1]tb.PrototypeParam {
    const pp: ?[1]tb.PrototypeParam = [1]tb.PrototypeParam{
        tb.PrototypeParam{
            .name = "$ret1",
            .dt = getType(t),
            .debug_type = getDebugType(m, t),
        },
    };
    return pp;
}

fn getPrototype(m: tb.Module, f: SSAFunction) error{OutOfMemory}!*tb.FunctionPrototype {
    if (prototypeMap == null) unreachable;
    var proto = prototypeMap.?.get(f.name);
    if (proto) |e| return e;

    var ret = getPrototypeParam(m, f.returnType);

    proto = m.createPrototype(tb.CallingConv.STDCALL, 0, null, if (f.returnType.type != .void) 1 else 0, if (ret == null) null else ret.?[0..], false);

    try prototypeMap.?.put(f.name, proto.?);

    return proto.?;
}

fn getExtern(m: tb.Module, f: SSAFunction) error{OutOfMemory}!*tb.Symbol {
    if (externMap == null) unreachable;
    var ext = externMap.?.get(f.name);
    if (ext) |e| return e;

    ext = m.externCreate(f.name, tb.ExternalType.SO_LOCAL);

    try externMap.?.put(f.name, ext.?);

    return ext.?;
}

pub fn codeGen(alloc: Allocator, ir: SSA, printAsm: bool, path: []const u8) error{OutOfMemory}!void {
    externMap = std.StringHashMap(*tb.Symbol).init(alloc);
    defer externMap.?.deinit();
    prototypeMap = std.StringHashMap(*tb.FunctionPrototype).init(alloc);
    defer prototypeMap.?.deinit();

    var a = tb.Arena.create("For main Module");
    defer a.destroy();

    const m = tb.Module.create(tb.Arch.X86_64, tb.System.LINUX, false);
    defer m.destroy();

    const sectionText = m.getText();

    var moduleFuncs = std.ArrayList(FunctionWs).init(alloc);

    var funcIterator = ir.funcs.iterator();
    var func = funcIterator.next();

    while (func != null) : (func = funcIterator.next()) {
        const f = try codeGenFunction(m, func.?.value_ptr.*);
        try moduleFuncs.append(f);
    }

    const startF = m.functionCreate("_start", tb.Linkage.PUBLIC);
    const startP = m.createPrototype(tb.CallingConv.STDCALL, 0, null, 0, null, false);
    const startWS = tb.Worklist.alloc();
    defer startWS.free();

    {
        const g = startF.graphBuilderEnter(sectionText, startP, startWS);
        defer g.exit();

        const mainExtern = try getExtern(m, ir.funcs.get("main").?);
        const mainPrototype = try getPrototype(m, ir.funcs.get("main").?);

        const ret = g.call(mainPrototype, 0, g.symbol(mainExtern), 0, null);
        const sysExit = g.uint(tb.typeI32(), 60);

        _ = g.syscall(tb.typeVoid(), 0, sysExit, 1, ret);

        g.ret(0, 0, null);
    }

    try moduleFuncs.append(.{
        .f = startF,
        .ws = startWS,
    });

    var w = true;

    while (w) : (w = m.ipo()) {
        for (moduleFuncs.items) |f| {
            _ = f.f.opt(f.ws, false);
        }
    }

    for (moduleFuncs.items) |f| {
        var feature: tb.FeatureSet = undefined;
        const out = f.f.codeGen(f.ws, a, &feature, true);
        if (printAsm)
            out.printAsm(c.stdout.*);
    }

    if (printAsm) return;

    const eb = m.objectExport(a, tb.DebugFormat.NONE);
    if (!eb.toFile(("mainModule.o"))) {
        std.log.err("Could not export object to file", .{});
        return;
    }

    var cmdObj = Commnad.init(alloc, &[_][]const u8{ "ld", "mainModule.o", "-o", path }, false);
    const resultObj = cmdObj.execute() catch {
        std.log.err("Could not link the generated object file", .{});
        return;
    };

    var cmdClean = Commnad.init(alloc, &[_][]const u8{ "rm", "mainModule.o" }, false);
    _ = cmdClean.execute() catch {
        std.log.err("Could not clean the generated object file", .{});
    };

    switch (resultObj) {
        .Exited => |x| if (x != 0) std.log.err("Could not link generated object file", .{}),
        else => std.log.err("Could not link generated object file", .{}),
    }
}

fn codeGenFunction(m: tb.Module, f: SSAFunction) error{OutOfMemory}!FunctionWs {
    const textSection = m.getText();

    const func = m.functionCreate(f.name, tb.Linkage.PUBLIC);
    const funcPrototype = try getPrototype(m, f);
    const funcWS = tb.Worklist.alloc();

    const g = func.graphBuilderEnter(textSection, funcPrototype, funcWS);

    for (f.body.items) |block| {
        const insts: []SSAInstruction = block.body.items;
        for (insts) |inst| {
            codeGenInstruction(g, f, inst);
        }
    }

    return FunctionWs{
        .f = func,
        .ws = funcWS,
    };
}

fn codeGenInstruction(g: tb.GraphBuilder, f: SSAFunction, inst: SSAInstruction) void {
    switch (inst) {
        .ret => |ret| {
            std.log.warn("Only parsing expr of return value as unsigned and I assume there is a return of unsigned", .{});
            var node = g.uint(getType(f.returnType), std.fmt.parseUnsigned(u64, ret.expr, 10) catch unreachable);
            g.ret(0, 1, @ptrCast(&node));
        },
        .intrinsic => unreachable,
    }
}
