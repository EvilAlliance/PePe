const std = @import("std");

const Parser = @import("Parser.zig");
const Program = Parser.Program;
const Primitive = Parser.Primitive;
const Function = Parser.StatementFunc;

pub fn typeCheck(p: Program) error{OutOfMemory}!bool {
    var err = false;
    if (p.funcs.get("_start")) |startF| {
        err = true;
        std.log.err("{s}:{}:{} {s} identifier is not available", .{ startF.loc.path, startF.loc.row, startF.loc.col, startF.name });
        startF.loc.print(std.log.err);
    }

    if (p.funcs.get("main") == null) {
        err = true;
        std.log.err(
            \\Main function must be defined 
            \\    fn main() u8 {{
            \\        return 0;
            \\    }}
        , .{});
    }

    var itFunc = p.funcs.iterator();
    var func = itFunc.next();

    while (func != null) : (func = itFunc.next()) {
        const retType = func.?.value_ptr.returnType;
        if (retType.type != .bool or retType.type != .void) {
            if ((retType.type == .signed or retType.type == .unsigned) and retType.size % 8 != 0 and retType.size <= 64) {
                err = true;
                std.log.err("Numeric types except float should be smaller of 64 bits and the module of 8 bit should be 0", .{});
                continue;
            } else if (retType.type == .float and retType.size % 32 != 0 and retType.size <= 64) {
                err = true;
                std.log.err("Numeric types except float should be smaller of 64 bits and the module of 32 bit should be 0", .{});
                continue;
            }
        }
        for (func.?.value_ptr.body.items) |stmt| {
            switch (stmt) {
                .ret => |ret| if (!retType.possibleValue(ret.expr)) {
                    err = true;
                    std.log.err("Rework Type Errors", .{});
                },
                else => continue,
            }
        }
    }

    return err;
}
