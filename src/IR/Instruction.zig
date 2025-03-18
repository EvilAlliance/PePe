const std = @import("std");

const IR = @import("IR.zig");
const Intrinsic = IR.Intrinsic;
const Return = IR.Return;

const Parser = @import("../Parser/Parser.zig");
const Statement = Parser.Statement;

const tb = @import("../libs/tb/tb.zig");
const tbHelper = @import("../TBHelper.zig");

pub const Instruction = union(enum) {
    intrinsic: Intrinsic,
    ret: Return,

    pub fn codeGen(self: @This(), g: tb.GraphBuilder, f: IR.Function) void {
        switch (self) {
            .ret => |ret| {
                std.log.warn("Only parsing expr of return value as unsigned and I assume there is a return of unsigned", .{});
                var node = ret.expr.codeGen(g, tbHelper.getType(f.returnType));
                g.ret(0, 1, @ptrCast(&node));
            },
            .intrinsic => unreachable,
        }
    }

    pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
        switch (self) {
            .intrinsic => |in| try in.toString(cont, d),
            .ret => |in| try in.toString(cont, d),
        }
    }
};
