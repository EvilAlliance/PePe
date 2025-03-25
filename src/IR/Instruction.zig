const std = @import("std");
const Logger = @import("../Logger.zig");

const IR = @import("IR.zig");
const Intrinsic = IR.Intrinsic;
const Return = IR.Return;
const Variable = IR.Variable;

const Parser = @import("../Parser/Parser.zig");
const Statement = Parser.Statement;

const tb = @import("../libs/tb/tb.zig");
const tbHelper = @import("../TBHelper.zig");

pub const Instruction = union(enum) {
    intrinsic: Intrinsic,
    ret: Return,
    variable: Variable,

    pub fn codeGen(self: @This(), g: tb.GraphBuilder, f: IR.Function, scope: *std.StringHashMap(*tb.Node)) std.mem.Allocator.Error!void {
        switch (self) {
            .ret => |ret| {
                Logger.log.warn("Only parsing expr of return value as unsigned and I assume there is a return of unsigned", .{});
                var node = ret.expr.codeGen(g, scope, f.returnType, tbHelper.getType(f.returnType));
                g.ret(0, 1, @ptrCast(&node));
            },
            .intrinsic => unreachable,
            .variable => |v| try scope.put(v.name, v.codeGen(g, scope)),
        }
    }

    pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) std.mem.Allocator.Error!void {
        switch (self) {
            .intrinsic => |in| try in.toString(cont, d),
            .ret => |in| try in.toString(cont, d),
            .variable => |in| try in.toString(cont, d),
        }
    }
};
