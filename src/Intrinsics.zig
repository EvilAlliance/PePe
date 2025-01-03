const std = @import("std");
const SSAIntrinsic = @import("IR.zig").SSAIntrinsic;

pub const IntrinsicFn = std.StaticStringMap(*const fn (*std.ArrayList(u8), SSAIntrinsic) error{OutOfMemory}!void).initComptime(.{
    .{ "@exit", &Intrinsic.exit },
});

const Intrinsic = struct {
    fn exit(cont: *std.ArrayList(u8), i: SSAIntrinsic) error{OutOfMemory}!void {
        std.debug.assert(i.args.items.len == 1);
        try cont.appendSlice("mov rax, 60\nmov rdi, ");
        try cont.appendSlice(i.args.items[0]);
        try cont.appendSlice("\nsyscall\n");
    }
};
