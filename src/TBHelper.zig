const tb = @import("libs/tb/tb.zig");
const Primitive = @import("./Parser.zig").Primitive;

const IR = @import("IR.zig");
const SSAFunction = IR.SSAFunction;

pub fn getType(t: Primitive) tb.DataType {
    return switch (t.type) {
        .bool => tb.typeBool(),
        .float => switch (t.size) {
            32 => tb.typeF32(),
            64 => tb.typeF64(),
            else => unreachable,
        },
        .signed, .unsigned => switch (t.size) {
            8 => tb.typeI8(),
            16 => tb.typeI16(),
            32 => tb.typeI32(),
            64 => tb.typeI64(),
            else => unreachable,
        },
        .void => tb.typeVoid(),
    };
}

pub fn getDebugType(m: tb.Module, t: Primitive) ?*tb.DebugType {
    return switch (t.type) {
        .bool => m.debugGetBool(),
        .float => switch (t.size) {
            32 => m.debugGetFloat32(),
            64 => m.debugGetFloat64(),
            else => unreachable,
        },
        .signed => m.debugGetInteger(true, t.size),
        .unsigned => m.debugGetInteger(false, t.size),
        .void => m.debugGetVoid(),
    };
}

fn getPrototypeParam(m: tb.Module, t: Primitive) [1]tb.PrototypeParam {
    const pp: [1]tb.PrototypeParam = [1]tb.PrototypeParam{
        tb.PrototypeParam{
            .name = "$ret1",
            .dt = getType(t),
            .debug_type = getDebugType(m, t),
        },
    };
    return pp;
}

pub fn getPrototype(m: tb.Module, returnType: Primitive) *tb.FunctionPrototype {
    var ret = getPrototypeParam(m, returnType);

    return m.createPrototype(tb.CallingConv.STDCALL, 0, null, 1, ret[0..], false);
}
