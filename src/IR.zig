const std = @import("std");
const Parser = @import("./Parser.zig");

const Program = Parser.Program;
const StatementFunc = Parser.StatementFunc;
const Statements = Parser.Statements;
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

    pub fn toIR(self: *IR) void {
        var it = self.program.funcs.iterator();
        var c = it.next();
        while (c != null) : (c = it.next())
            self.transformFuncToSSA(c.?.value_ptr.*);
    }

    fn transformFuncToSSA(self: *IR, sf: StatementFunc) void {
        var f = SSAFunction{
            .name = sf.name,
            .body = std.ArrayList(SSABlock).init(self.alloc),
            .returnType = sf.returnType,
        };

        self.transformBodyToSSA(&f.body, sf.body, std.mem.eql(u8, f.name, "main"));

        self.ssa.funcs.put(f.name, f) catch unreachable;
    }

    fn transformBodyToSSA(self: *IR, body: *std.ArrayList(SSABlock), ss: Statements, isMain: bool) void {
        var b = SSABlock{
            .name = "1",
            .body = std.ArrayList(SSAInstruction).init(self.alloc),
        };

        for (ss.items) |s| {
            switch (s) {
                .ret => |ret| {
                    if (isMain) {
                        b.body.append(SSAInstruction{
                            .intrinsic = SSAIntrinsic{
                                .name = "@exit",
                                .args = .{ ret.expr, null, null, null, null, null },
                            },
                        }) catch unreachable;
                    } else unreachable;
                },
                .func => |_| unreachable,
            }
        }

        body.append(b) catch unreachable;
    }

    pub fn toString(self: *@This(), alloc: std.mem.Allocator) error{OutOfMemory}!std.ArrayList(u8) {
        var cont = std.ArrayList(u8).init(alloc);

        try self.ssa.toString(&cont);

        return cont;
    }
};
