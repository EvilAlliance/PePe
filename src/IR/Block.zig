const std = @import("std");

const Parser = @import("../Parser/Parser.zig");
const Statements = Parser.Statements;

const IR = @import("IR.zig");
const Instruction = IR.Instruction;

name: []const u8,
//args: void,
body: std.ArrayList(Instruction),

pub fn transformBodyToSSA(alloc: std.mem.Allocator, body: *std.ArrayList(@This()), ss: Statements) error{OutOfMemory}!void {
    var b = @This(){
        .name = "1",
        .body = std.ArrayList(Instruction).init(alloc),
    };

    for (ss.items) |s| {
        const ins = try Instruction.toSSA(s);
        try b.body.append(ins);
    }

    try body.append(b);
}

pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
    for (0..d) |_|
        try cont.append(' ');

    try cont.appendSlice("Block:\n");

    for (0..d + 2) |_|
        try cont.append(' ');

    try cont.appendSlice("Name: ");
    try cont.appendSlice(self.name);
    try cont.append('\n');

    for (0..d + 2) |_|
        try cont.append(' ');

    try cont.appendSlice("Body:\n");

    for (self.body.items) |in| {
        try in.toString(cont, d + 4);
    }
}
