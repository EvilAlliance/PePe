const std = @import("std");
const Allocator = std.mem.Allocator;

const Parser = @import("Parser.zig");
const Program = Parser.Program;
const Primitive = Parser.Primitive;
const Function = Parser.StatementFunc;

const TypeError = union(enum) {
    unavailableFunctionIdentifier: Function,
    expectedFunction: []const u8,
    valueNotCompatibleWithType: struct {
        primitive: Primitive,
        value: []const u8,
    },
    invalidType: Primitive,
};

pub fn typeCheck(p: Program, alloc: Allocator) error{OutOfMemory}!bool {
    var typeError = std.ArrayList(TypeError).init(alloc);
    if (p.funcs.get("_start")) |startF| {
        try typeError.append(TypeError{ .unavailableFunctionIdentifier = startF });
    }

    if (p.funcs.get("main") == null) {
        try typeError.append(TypeError{ .expectedFunction = "main" });
    }

    var itFunc = p.funcs.iterator();
    var func = itFunc.next();

    while (func != null) : (func = itFunc.next()) {
        const retType = func.?.value_ptr.returnType;
        if (retType.type != .bool or retType.type != .void) {
            if ((retType.type == .signed or retType.type == .unsigned) and retType.size % 8 != 0 and retType.size <= 64) {
                try typeError.append(TypeError{ .invalidType = retType });
                continue;
            } else if (retType.type == .float and retType.size % 32 != 0 and retType.size <= 64) {
                try typeError.append(TypeError{ .invalidType = retType });
                continue;
            }
        }
        for (func.?.value_ptr.body.items) |stmt| {
            switch (stmt) {
                .ret => |ret| if (!retType.possibleValue(ret.expr)) {
                    try typeError.append(TypeError{
                        .valueNotCompatibleWithType = .{
                            .primitive = retType,
                            .value = ret.expr,
                        },
                    });
                },
                else => continue,
            }
        }
    }

    for (typeError.items) |err| {
        switch (err) {
            .expectedFunction => |e| std.log.err("{s} function must be defined", .{e}),
            .unavailableFunctionIdentifier => |e| std.log.err("{s}:{}:{} {s} identifier is not available", .{ e.loc.path, e.loc.row, e.loc.col, e.name }),
            .invalidType => |e| {
                if (e.type != .bool or e.type != .void) {
                    if ((e.type == .signed or e.type == .unsigned) and e.size % 8 != 0 and e.size <= 64) {
                        std.log.err("Numeric types except float should be smaller of 64 bits and the module of 8 bit should be 0", .{});
                    } else if (e.type == .float and e.size % 32 != 0 and e.size <= 64) {
                        std.log.err("Numeric types except float should be smaller of 64 bits and the module of 32 bit should be 0", .{});
                    }
                }
            },
            .valueNotCompatibleWithType => std.log.err("Rework Type Errors", .{}),
        }
    }

    return typeError.items.len > 0;
}
