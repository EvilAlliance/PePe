const std = @import("std");

const Parser = @import("./Parser.zig");
const Function = Parser.Function;

funcs: std.StringHashMap(Function),

pub fn init(alloc: std.mem.Allocator) @This() {
    return .{
        .funcs = std.StringHashMap(Function).init(alloc),
    };
}

pub fn deinit(self: *@This()) void {
    self.funcs.deinit();
}

pub fn toString(self: @This(), cont: *std.ArrayList(u8)) std.mem.Allocator.Error!void {
    var it = self.funcs.iterator();

    while (it.next()) |state| {
        try state.value_ptr.toString(cont, 0);
    }
}
