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
