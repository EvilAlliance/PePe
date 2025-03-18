const std = @import("std");

const Parser = @import("../Parser/Parser.zig");
const Statements = Parser.Statements;
const Statement = Parser.Statement;
const Expression = Parser.Expression;
const Primitive = Parser.Primitive;

pub const Intrinsic = @import("./Intrinsic.zig");
pub const Return = @import("./Return.zig");
pub const Instruction = @import("./Instruction.zig").Instruction;
pub const Block = @import("./Block.zig");
pub const Function = @import("./Function.zig");
pub const Program = @import("./Program.zig");

const tb = @import("../libs/tb/tb.zig");
const tbHelper = @import("../TBHelper.zig");

program: *Parser.Program,
ssa: Program,
alloc: std.mem.Allocator,

pub fn init(p: *Parser.Program, alloc: std.mem.Allocator) @This() {
    return @This(){
        .alloc = alloc,
        .program = p,
        .ssa = Program{
            .funcs = std.StringHashMap(Function).init(alloc),
        },
    };
}

pub fn toIR(self: *@This(), m: tb.Module) error{OutOfMemory}!void {
    var it = self.program.funcs.iterator();
    while (it.next()) |c| {
        const func = c.value_ptr.*;
        const f = try Function.transformToSSA(self.alloc, func, m);

        try self.ssa.funcs.put(f.name, f);
    }
}

pub fn toString(self: *@This(), alloc: std.mem.Allocator) error{OutOfMemory}!std.ArrayList(u8) {
    var cont = std.ArrayList(u8).init(alloc);

    try self.ssa.toString(&cont);

    return cont;
}
