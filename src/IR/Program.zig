const std = @import("std");

const IR = @import("IR.zig");
const Function = IR.Function;

funcs: std.StringHashMap(Function),

pub fn toString(self: @This(), cont: *std.ArrayList(u8)) error{OutOfMemory}!void {
    var it = self.funcs.iterator();

    while (it.next()) |state| {
        try state.value_ptr.toString(cont, 0);
    }
}

pub fn init(alloc: std.mem.Allocator) @This() {
    return .{
        .funcs = std.StringHashMap(Function).init(alloc),
    };
}

pub fn deinit(self: *@This()) void {
    self.funcs.deinit();
}
