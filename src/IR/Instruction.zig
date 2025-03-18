const std = @import("std");

const IR = @import("IR.zig");
const Intrinsic = IR.Intrinsic;
const Return = IR.Return;

const Parser = @import("../Parser/Parser.zig");
const Statement = Parser.Statement;

pub const Instruction = union(enum) {
    intrinsic: Intrinsic,
    ret: Return,

    pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
        switch (self) {
            .intrinsic => |in| try in.toString(cont, d),
            .ret => |in| try in.toString(cont, d),
        }
    }
};
