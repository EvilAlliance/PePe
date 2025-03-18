const std = @import("std");

const Parser = @import("../Parser/Parser.zig");
const Expression = Parser.Expression;

const tb = @import("../libs/tb/tb.zig");

name: []const u8,
args: std.ArrayList(Expression),

fn init(alloc: std.mem.Allocator, name: []const u8) @This() {
    return @This(){
        .name = name,
        .args = std.ArrayList(Expression).init(alloc),
    };
}

pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
    for (0..d) |_|
        try cont.append(' ');

    try cont.appendSlice("call ");
    try cont.appendSlice(self.name);
    try cont.append('(');

    for (self.args.items, 0..) |arg, i| {
        if (i > 0)
            try cont.appendSlice(", ");

        try arg.toString(cont, d);
    }

    try cont.append(')');

    try cont.append('\n');
}

pub const Function = std.StaticStringMap(*const fn (g: tb.GraphBuilder, param: [*c]?*tb.Node, paramCounter: i32) ?*tb.Node).initComptime(.{
    .{ "@exit", &exit },
});

fn exit(g: tb.GraphBuilder, param: [*c]?*tb.Node, paramCounter: i32) ?*tb.Node {
    const sysExit = g.uint(tb.typeI32(), 60);
    return g.syscall(tb.typeVoid(), 0, sysExit, paramCounter, param);
}
