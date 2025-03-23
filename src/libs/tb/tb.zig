const cc = @cImport({
    @cInclude("stdio.h");
});

const tb = @import("./tbHeader.zig");

pub const Arch = tb.Arch;
pub const System = tb.System;
pub const Linkage = tb.Linkage;
pub const CallingConv = tb.CallingConv;
pub const DebugFormat = tb.DebugFormat;

pub const ModuleSectionHandle = tb.ModuleSectionHandle;
pub const FunctionPrototype = tb.FunctionPrototype;
pub const PrototypeParam = tb.PrototypeParam;
pub const DebugType = tb.DebugType;
pub const DataType = tb.DataType;
pub const Node = tb.Node;
pub const ExternalType = tb.ExternalType;
pub const Symbol = tb.Symbol;
pub const FeatureSet = tb.FeatureSet;
pub const CharUnits = tb.CharUnits;

pub const NodeType = tb.NodeTypeEnum;
pub const ArithmeticBehavior = tb.ArithmeticBehavior;

pub const typeTuple = tb.typeTuple;
pub const typeControl = tb.typeControl;
pub const typeVoid = tb.typeVoid;
pub const typeBool = tb.typeBool;
pub const typeI8 = tb.typeI8;
pub const typeI16 = tb.typeI16;
pub const typeI32 = tb.typeI32;
pub const typeI64 = tb.typeI64;
pub const typeF32 = tb.typeF32;
pub const typeF64 = tb.typeF64;
pub const createPTR = tb.createPTR;
pub const createMemory = tb.createMemory;
pub const createPTRN = tb.createPTRN;

pub const Arena = struct {
    arena: tb.Arena,

    pub inline fn create(a: *Arena, tag: [*c]const u8) void {
        tb.arenaCreate(&a.arena, tag);
    }

    pub inline fn destroy(self: *@This()) void {
        tb.arenaDestroy(&self.arena);
    }

    pub inline fn clear(self: *@This()) void {
        tb.arenaClear(&self.arena);
    }

    pub inline fn isEmpty(self: *@This()) bool {
        return tb.arenaIsEmpty(&self.arena);
    }

    pub inline fn save(self: *@This()) tb.ArenaSavepoint {
        return tb.arenaSave(&self.arena);
    }

    pub inline fn restore(self: *@This(), sp: tb.ArenaSavepoint) void {
        tb.arenaRestore(&self.arena, sp);
    }
};

pub const Module = struct {
    m: *tb.Module,

    pub inline fn create(arch: tb.Arch, sys: tb.System, isJit: bool) Module {
        var m: Module = undefined;
        m.m = tb.moduleCreate(arch, sys, isJit) orelse unreachable;
        return m;
    }

    pub inline fn createForHost() Module {
        var m: Module = undefined;
        m.m = tb.moduleCreateForHost();
        return m;
    }

    pub inline fn destroy(self: @This()) void {
        tb.moduleDestroy(self.m);
    }

    pub inline fn functionCreate(self: @This(), name: []const u8, linkage: Linkage) Function {
        return Function.create(self, name, linkage);
    }

    pub inline fn ipo(self: @This()) bool {
        return tb.moduleIpo(self.m);
    }

    pub inline fn objectExport(self: @This(), a: *Arena, debugFmt: DebugFormat) ExportBuffer {
        const eb = tb.moduleObjectExport(self.m, &a.arena, debugFmt);
        return ExportBuffer{ .eb = eb };
    }

    pub inline fn getText(self: @This()) tb.ModuleSectionHandle {
        return tb.moduleGetText(self.m);
    }
    pub inline fn getRdata(self: @This()) tb.ModuleSectionHandle {
        return tb.moduleGetRData(self.m);
    }
    pub inline fn getData(self: @This()) tb.ModuleSectionHandle {
        return tb.moduleGetData(self.m);
    }
    pub inline fn getTLS(self: @This()) tb.ModuleSectionHandle {
        return tb.moduleGetTLS(self.m);
    }

    pub inline fn createPrototype(self: @This(), c: CallingConv, paramCount: usize, params: [*c]PrototypeParam, returnCount: usize, returns: [*c]PrototypeParam, hasVarArgs: bool) *FunctionPrototype {
        return tb.prototypeCreate(self.m, c, paramCount, params, returnCount, returns, hasVarArgs);
    }

    pub inline fn externCreate(self: @This(), name: []const u8, t: ExternalType) *Symbol {
        return tb.externCreate(self.m, @intCast(name.len), name.ptr, t);
    }

    pub inline fn debugGetVoid(self: @This()) ?*DebugType {
        return tb.debugGetVoid(self.m);
    }
    pub inline fn debugGetBool(self: @This()) ?*DebugType {
        return tb.debugGetBool(self.m);
    }
    pub inline fn debugGetInteger(self: @This(), isSigned: bool, size: c_int) ?*DebugType {
        return tb.debugGetInteger(self.m, isSigned, size);
    }
    pub inline fn debugGetFloat32(self: @This()) ?*DebugType {
        return tb.debugGetFloat32(self.m);
    }
    pub inline fn debugGetFloat64(self: @This()) ?*DebugType {
        return tb.debugGetFloat64(self.m);
    }
};

pub const Function = struct {
    f: *tb.Function,

    pub inline fn create(m: Module, name: []const u8, linkage: Linkage) Function {
        var f: Function = undefined;
        f.f = tb.functionCreate(m.m, @intCast(name.len), @ptrCast(name), linkage) orelse unreachable;
        return f;
    }

    pub inline fn graphBuilderEnter(self: @This(), section: ModuleSectionHandle, proto: *FunctionPrototype, ws: ?Worklist) GraphBuilder {
        return GraphBuilder.enter(self, section, proto, ws);
    }

    pub inline fn codeGen(self: @This(), ws: ?Worklist, a: ?*Arena, f: *FeatureSet, emit_asm: bool) FunctionOutput {
        const out = tb.codegen(self.f, if (ws) |w| w.ws else null, if (a) |arena| &arena.arena else null, f, emit_asm) orelse unreachable;

        return FunctionOutput{ .fo = out };
    }

    pub inline fn opt(self: @This(), ws: ?Worklist, perserve_types: bool) bool {
        return tb.opt(self.f, if (ws) |w| w.ws else null, perserve_types);
    }

    pub inline fn print(self: @This()) void {
        tb.print(self.f);
    }

    pub inline fn printDump(self: @This()) void {
        tb.printDump(self.f);
    }
};

pub const GraphBuilder = struct {
    g: *tb.GraphBuilder,

    pub inline fn enter(f: Function, section: ModuleSectionHandle, proto: *FunctionPrototype, ws: ?Worklist) @This() {
        return @This(){ .g = tb.builderEnter(f.f, section, proto, if (ws) |w| w.ws else null) orelse unreachable };
    }

    pub inline fn exit(self: @This()) void {
        tb.builderExit(self.g);
    }

    pub inline fn call(self: @This(), proto: *FunctionPrototype, mem_var: i32, target: *Node, arg_count: i32, args: [*c]?*Node) [*c]?*Node {
        return tb.builderCall(self.g, proto, mem_var, target, arg_count, args);
    }

    pub inline fn syscall(self: @This(), dt: DataType, mem_var: i32, target: *Node, arg_count: i32, args: [*c]?*Node) ?*Node {
        return tb.builderSyscall(self.g, dt, mem_var, target, arg_count, args);
    }

    pub inline fn symbol(self: @This(), sym: *Symbol) *Node {
        return tb.builderSymbol(self.g, sym) orelse unreachable;
    }

    pub inline fn uint(self: @This(), dt: DataType, x: u64) *Node {
        return tb.builderUint(self.g, dt, x) orelse unreachable;
    }

    pub inline fn sint(self: @This(), dt: DataType, x: i64) *Node {
        return tb.builderSint(self.g, dt, x) orelse unreachable;
    }

    pub inline fn binopInt(self: @This(), t: NodeType, a: *Node, b: *Node, ab: ArithmeticBehavior) *Node {
        return tb.builderBinopInt(self.g, @intFromEnum(t), a, b, ab) orelse unreachable;
    }

    pub inline fn ret(self: @This(), mem_var: i32, arg_count: i32, args: [*c]?*Node) void {
        return tb.builderRet(self.g, mem_var, arg_count, args);
    }

    pub inline fn neg(self: @This(), src: *Node) *Node {
        return tb.builderNeg(self.g, src) orelse unreachable;
    }

    pub inline fn unary(self: @This(), t: NodeType, src: *Node) *Node {
        return tb.builderUnary(self.g, t, src) orelse unreachable;
    }

    pub inline fn @"if"(self: @This(), cond: *Node, paths: *[2]*Node) void {
        tb.builderIf(self.g, cond, @ptrCast(&paths[0]));
    }

    pub inline fn loop(self: @This()) *Node {
        return tb.builderLoop(self.g) orelse unreachable;
    }

    pub inline fn labelMake(self: @This()) *Node {
        return tb.builderLabelMake(self.g) orelse unreachable;
    }

    pub inline fn labelClone(self: @This(), label: *Node) *Node {
        return tb.builderLabelClone(self.g, label) orelse unreachable;
    }

    pub inline fn labelSet(self: @This(), label: *Node) ?*Node {
        return tb.builderLabelSet(self.g, label);
    }

    pub inline fn labelKill(self: @This(), label: *Node) void {
        tb.builderLabelKill(self.g, label);
    }

    pub inline fn local(self: @This(), size: CharUnits, a: CharUnits) *Node {
        return tb.builderLocal(self.g, size, a) orelse unreachable;
    }

    pub inline fn store(self: @This(), mem_var: i32, ctrlDep: bool, addr: *Node, val: *Node, a: CharUnits, isVolatile: bool) void {
        tb.builderStore(self.g, mem_var, ctrlDep, addr, val, a, isVolatile);
    }

    pub inline fn load(self: @This(), mem_var: i32, ctrlDep: bool, dt: DataType, addr: *Node, a: CharUnits, isVolatile: bool) *Node {
        return tb.builderLoad(self.g, mem_var, ctrlDep, dt, addr, a, isVolatile) orelse unreachable;
    }

    pub inline fn br(self: @This(), label: *Node) void {
        tb.builderBr(self.g, label);
    }

    pub inline fn cmp(self: @This(), t: NodeType, a: *Node, b: *Node) *Node {
        return tb.builderCmp(self.g, @intFromEnum(t), a, b) orelse unreachable;
    }
};

pub const Worklist = struct {
    ws: *tb.Worklist,

    pub inline fn alloc() @This() {
        const ws = tb.worklistAlloc();
        return @This(){ .ws = ws orelse unreachable };
    }

    pub inline fn free(ws: @This()) void {
        tb.worklistFree(ws.ws);
    }
};

pub const FunctionOutput = struct {
    fo: *tb.FunctionOutput,

    pub inline fn printAsm(self: @This(), f: *cc.FILE) void {
        tb.outputPrintAsm(self.fo, f);
    }
};

pub const ExportBuffer = struct {
    eb: tb.ExportBuffer,

    pub inline fn toFile(self: @This(), path: [:0]const u8) bool {
        return tb.exportBufferToFile(self.eb, @as([*c]const u8, path.ptr));
    }
};

pub const Jit = struct {
    jit: *tb.JIT,

    pub inline fn begin(m: Module, jit_heap_capacity: usize) @This() {
        const jit = tb.jitBegin(m.m, jit_heap_capacity) orelse unreachable;

        return @This(){
            .jit = jit,
        };
    }

    pub inline fn placeFunction(self: @This(), f: Function) ?*anyopaque {
        return tb.jitPlanceFunction(self.jit, f.f);
    }
};
