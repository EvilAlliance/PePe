const std = @import("std");
const Logger = @import("Logger.zig");

const Parser = @import("./Parser/Parser.zig");
const Program = Parser.Program;
const Primitive = Parser.Primitive;
const Function = Parser.StatementFunc;

pub fn typeCheck(p: Program) !bool {
    var err = false;
    if (p.funcs.get("main") == null) {
        err = true;
        Logger.log.err(
            \\Main function must be defined 
            \\    fn main() u8 {{
            \\        return 0;
            \\    }}
        , .{});
    }

    if (p.funcs.get("_start")) |startF| {
        err = true;
        Logger.logLocation.err(startF.loc, "identifier _start is not available", .{});
    }

    var itFunc = p.funcs.iterator();
    while (itFunc.next()) |func| {
        const retType = func.value_ptr.returnType;
        if (retType.type != .bool or retType.type != .void) {
            if ((retType.type == .signed or retType.type == .unsigned) and retType.size % 8 != 0 and retType.size <= 64) {
                err = true;
                Logger.log.err("Numeric types except float should be smaller of 64 bits and the module of 8 bit should be 0", .{});
                continue;
            } else if (retType.type == .float and retType.size % 32 != 0 and retType.size <= 64) {
                err = true;
                Logger.log.err("Numeric types except float should be smaller of 64 bits and the module of 32 bit should be 0", .{});
                continue;
            }
        }
        for (func.value_ptr.body.items) |stmt| {
            switch (stmt) {
                .ret => |ret| if (!retType.possibleValue(ret.expr)) {
                    err = true;
                    Logger.log.err("Rework Type Errors", .{});
                },
                else => continue,
            }
        }
    }

    return err;
}
