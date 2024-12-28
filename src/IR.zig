const std = @import("std");
const Parser = @import("./Parser.zig");

const Program = Parser.Program;
const StatementFunc = Parser.StatementFunc;
const Statements = Parser.Statements;
const Statement = Parser.Statement;
const Expression = Parser.Expression;

const SSAIntrinsic = struct {
    name: []const u8,
    args: [6]?Expression,

    pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
        for (0..d) |_|
            try cont.append(' ');

        try cont.appendSlice("call ");
        try cont.appendSlice(self.name);
        try cont.append('(');

        if (self.args[0]) |arg|
            try cont.appendSlice(arg);
        for (self.args[1..], 0..) |arg, i| {
            if (arg == null) break;

            if (i + 2 < self.args.len or self.args[i + 2] != null)
                try cont.appendSlice(", ");

            try cont.appendSlice(arg.?);
        }

        try cont.append(')');

        try cont.append('\n');
    }
};

const SSAInstruction = union(enum) {
    intrinsic: SSAIntrinsic,

    fn toSSA(s: Statement, isMain: bool) SSAInstruction {
        switch (s) {
            .ret => |ret| {
                if (isMain) {
                    return SSAInstruction{
                        .intrinsic = SSAIntrinsic{
                            .name = "@exit",
                            .args = .{ ret.expr, null, null, null, null, null },
                        },
                    };
                } else unreachable;
            },
            .func => |_| unreachable,
        }
        unreachable;
    }

    pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
        switch (self) {
            .intrinsic => |in| try in.toString(cont, d),
        }
    }
};

const SSABlock = struct {
    name: []const u8,
    //args: void,
    body: std.ArrayList(SSAInstruction),

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
};

const SSAFunction = struct {
    name: []const u8,
    //args: void,
    body: std.ArrayList(SSABlock),
    returnType: []const u8,

    fn transformToSSA(alloc: std.mem.Allocator, sf: StatementFunc) SSAFunction {
        var f = SSAFunction{
            .name = sf.name,
            .body = std.ArrayList(SSABlock).init(alloc),
            .returnType = sf.returnType,
        };

        transformBodyToSSA(alloc, &f.body, sf.body, std.mem.eql(u8, f.name, "main"));

        return f;
    }

    fn transformBodyToSSA(alloc: std.mem.Allocator, body: *std.ArrayList(SSABlock), ss: Statements, isMain: bool) void {
        var b = SSABlock{
            .name = "1",
            .body = std.ArrayList(SSAInstruction).init(alloc),
        };

        for (ss.items) |s| {
            const ins = SSAInstruction.toSSA(s, isMain);
            b.body.append(ins) catch unreachable;
        }

        body.append(b) catch unreachable;
    }

    pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
        for (0..d) |_|
            try cont.append(' ');

        try cont.appendSlice("Function:\n");

        for (0..d + 2) |_|
            try cont.append(' ');

        try cont.appendSlice("Name: ");
        try cont.appendSlice(self.name);
        try cont.append('\n');

        for (0..d + 2) |_|
            try cont.append(' ');

        try cont.appendSlice("Return Type: ");
        try cont.appendSlice(self.returnType);
        try cont.append('\n');

        for (0..d + 2) |_|
            try cont.append(' ');

        try cont.appendSlice("Blocks:\n");

        for (self.body.items) |block| {
            try block.toString(cont, d + 4);
        }
    }
};

const SSA = struct {
    funcs: std.StringHashMap(SSAFunction),

    pub fn toString(self: @This(), cont: *std.ArrayList(u8)) error{OutOfMemory}!void {
        var it = self.funcs.iterator();

        var state = it.next();
        while (state != null) : (state = it.next()) {
            try state.?.value_ptr.toString(cont, 0);
        }
    }
};

pub const IR = struct {
    program: *Program,
    ssa: SSA,
    alloc: std.mem.Allocator,

    pub fn init(p: *Program, alloc: std.mem.Allocator) IR {
        return IR{
            .alloc = alloc,
            .program = p,
            .ssa = SSA{
                .funcs = std.StringHashMap(SSAFunction).init(alloc),
            },
        };
    }

    pub fn toIR(self: *IR) std.mem.Allocator.Error!void {
        var it = self.program.funcs.iterator();
        var c = it.next();
        while (c != null) : (c = it.next()) {
            const f = SSAFunction.transformToSSA(self.alloc, c.?.value_ptr.*);

            try self.ssa.funcs.put(f.name, f);
        }
    }

    pub fn toString(self: *@This(), alloc: std.mem.Allocator) error{OutOfMemory}!std.ArrayList(u8) {
        var cont = std.ArrayList(u8).init(alloc);

        try self.ssa.toString(&cont);

        return cont;
    }
};
