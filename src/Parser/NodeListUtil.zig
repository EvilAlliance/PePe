const std = @import("std");
const Parser = @import("./Parser.zig");

pub fn addNode(arr: *std.ArrayList(Parser.Node), node: Parser.Node) std.mem.Allocator.Error!usize {
    const index = arr.items.len;
    try arr.append(node);
    return index;
}

pub fn reserveNode(arr: *std.ArrayList(Parser.Node), node: Parser.Node) std.mem.Allocator.Error!*Parser.Node {
    const index = arr.items.len;
    try arr.append(node);
    return &arr[index];
}

pub fn reserveNodeIndex(arr: *std.ArrayList(Parser.Node), node: Parser.Node) std.mem.Allocator.Error!usize {
    const index = arr.items.len;
    try arr.append(node);
    return index;
}
