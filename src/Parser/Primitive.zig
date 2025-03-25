const std = @import("std");
const assert = std.debug.assert;

const Parser = @import("./Parser.zig");
const Expression = Parser.Expression;

type: enum {
    unsigned,
    signed,
    float,
    bool,
    void,
},

size: u8,

pub fn getType(str: []const u8) @This() {
    var t: @This() = undefined;

    if (str[0] == 'i' or str[0] == 'u' or str[0] == 'f') {
        assert(str.len > 1 and str.len < 4);
        switch (str[0]) {
            'i' => t.type = .signed,
            'u' => t.type = .unsigned,
            'f' => t.type = .float,
            else => unreachable,
        }

        t.size = std.fmt.parseUnsigned(u8, str[1..], 10) catch unreachable;
    } else if (std.mem.eql(u8, str, "void")) {
        t.size = 0;
        t.type = .void;
    } else if (std.mem.eql(u8, str, "bool")) {
        t.size = 1;
        t.type = .bool;
    }

    return t;
}

pub fn possibleValue(self: @This(), expr: *Expression) bool {
    _ = self;
    _ = expr;
    return true;
    // TODO: I do not know how to do it
    // switch (self.type) {
    //     .void => return expr.expr.str.len == 0,
    //     .bool => {
    //         if (expr.expr.str.len == 1) {
    //             return expr.expr.str[0] == '0' or expr.expr.str[0] == '1';
    //         }
    //         return std.mem.eql(u8, expr.expr.str, "false") or std.mem.eql(u8, expr.expr.str, "true");
    //     },
    //     .signed => {
    //         if (self.size == 8) {
    //             _ = std.fmt.parseInt(i8, expr.expr.str, 10) catch return false;
    //         } else if (self.size == 16) {
    //             _ = std.fmt.parseInt(i16, expr.expr.str, 10) catch return false;
    //         } else if (self.size == 32) {
    //             _ = std.fmt.parseInt(i32, expr.expr.str, 10) catch return false;
    //         } else if (self.size == 64) {
    //             _ = std.fmt.parseInt(i64, expr.expr.str, 10) catch return false;
    //         }
    //         return true;
    //     },
    //     .unsigned => {
    //         if (self.size == 8) {
    //             _ = std.fmt.parseUnsigned(u8, expr.expr.str, 10) catch return false;
    //         } else if (self.size == 16) {
    //             _ = std.fmt.parseUnsigned(u16, expr.expr.str, 10) catch return false;
    //         } else if (self.size == 32) {
    //             _ = std.fmt.parseUnsigned(u32, expr.expr.str, 10) catch return false;
    //         } else if (self.size == 64) {
    //             _ = std.fmt.parseUnsigned(u64, expr.expr.str, 10) catch return false;
    //         }
    //         return true;
    //     },
    //     .float => {
    //         if (self.size == 32) {
    //             _ = std.fmt.parseFloat(f32, expr.expr.str) catch return false;
    //         } else if (self.size == 64) {
    //             _ = std.fmt.parseFloat(f64, expr.expr.str) catch return false;
    //         }
    //         return true;
    //     },
    // }
}

pub fn toString(self: @This(), cont: *std.ArrayList(u8)) std.mem.Allocator.Error!void {
    const size = try std.fmt.allocPrint(cont.allocator, "{}", .{self.size});
    try switch (self.type) {
        .void => cont.appendSlice("void"),
        .bool => cont.appendSlice("bool"),
        .float => {
            try cont.append('f');
            try cont.appendSlice(size);
        },
        .signed => {
            try cont.append('i');
            try cont.appendSlice(size);
        },
        .unsigned => {
            try cont.append('u');
            try cont.appendSlice(size);
        },
    };
}
