const std = @import("std");
const Parser = @import("Parser.zig");

pub const Program = std.StringHashMap(usize);
pub const NodeList = std.ArrayList(Parser.Node);

alloc: std.mem.Allocator,
source: [:0]const u8,

functions: Program,
nodeList: NodeList,

pub fn init(alloc: std.mem.Allocator, funcs: Program, nl: NodeList, source: [:0]const u8) @This() {
    return @This(){
        .alloc = alloc,
        .source = source,
        .functions = funcs,
        .nodeList = nl,
    };
}

pub fn deinit(self: @This()) void {
    self.source.deinit();
    self.functions.deinit();
    self.nodeList.deinit();
}
