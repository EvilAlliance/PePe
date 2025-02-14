const std = @import("std");
const ir = @import("IR.zig");

const Allocator = std.mem.Allocator;
const SSA = ir.SSA;
const SSAFunction = ir.SSAFunction;
