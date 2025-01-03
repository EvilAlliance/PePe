const std = @import("std");
const ir = @import("IR.zig");

const Allocator = std.mem.Allocator;
const SSA = ir.SSA;
const SSAFunction = ir.SSAFunction;

pub fn codeGen(alloc: Allocator, prog: SSA) error{OutOfMemory}!std.ArrayList(u8) {
    var cont = std.ArrayList(u8).init(alloc);

    try cont.appendSlice("format ELF64 executable\nsegment readable executable\nentry main\n");

    var it = prog.funcs.iterator();

    var state = it.next();
    while (state != null) : (state = it.next()) {
        try codeGenFunction(&cont, state.?.value_ptr.*);
    }

    return cont;
}

fn codeGenFunction(cont: *std.ArrayList(u8), f: SSAFunction) !void {
    try cont.appendSlice(f.name);
    try cont.appendSlice(":\n");

    const block = f.body.items[0];

    for (block.body.items) |i| {
        try i.emitFasm(cont);
    }
}
