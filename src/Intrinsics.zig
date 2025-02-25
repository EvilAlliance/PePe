const std = @import("std");
const SSAIntrinsic = @import("IR.zig").SSAIntrinsic;

const tb = @import("./libs/tb/tb.zig");

pub const IntrinsicFn = std.StaticStringMap(*const fn (g: tb.GraphBuilder, param: [*c]?*tb.Node, paramCounter: i32) ?*tb.Node).initComptime(.{
    .{ "@exit", &Intrinsic.exit },
});

const Intrinsic = struct {
    fn exit(g: tb.GraphBuilder, param: [*c]?*tb.Node, paramCounter: i32) ?*tb.Node {
        const sysExit = g.uint(tb.typeI32(), 60);
        return g.syscall(tb.typeVoid(), 0, sysExit, paramCounter, param);
    }
};
