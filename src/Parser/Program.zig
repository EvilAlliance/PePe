const std = @import("std");

const Function = @import("./Function.zig");

funcs: std.StringArrayHashMap(Function),


pub fn toString(self: @This(), cont: *std.ArrayList(u8)) error{OutOfMemory}!void {
    var it = self.funcs.iterator();

    while (it.next()) |state| {
        try state.value_ptr.toString(cont, 0);
    }
}
