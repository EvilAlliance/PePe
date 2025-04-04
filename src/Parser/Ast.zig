const std = @import("std");
const Parser = @import("Parser.zig");

pub const Program = std.StringHashMap(usize);
pub const NodeList = std.ArrayList(Parser.Node);

alloc: std.mem.Allocator,

functions: Program,
nodeList: NodeList,

pub fn init(alloc: std.mem.Allocator, funcs: Program, nl: NodeList) @This() {
    return @This(){
        .alloc = alloc,
        .functions = funcs,
        .nodeList = nl,
    };
}

pub fn deinit(self: @This()) void {
    self.functions.deinit();
    self.nodeList.deinit();
}
