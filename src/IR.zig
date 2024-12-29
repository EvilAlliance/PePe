const std = @import("std");
const Parser = @import("./Parser.zig");

const Program = Parser.Program;
const StatementFunc = Parser.StatementFunc;
const Statements = Parser.Statements;
const Statement = Parser.Statement;
const Expression = Parser.Expression;

const SSAIntrinsic = struct {
    name: []const u8,
    args: std.ArrayList(Expression),

    fn init(alloc: std.mem.Allocator, name: []const u8) SSAIntrinsic {
        return SSAIntrinsic{
            .name = name,
            .args = std.ArrayList(Expression).init(alloc),
        };
    }

    pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
        for (0..d) |_|
            try cont.append(' ');

        try cont.appendSlice("call ");
        try cont.appendSlice(self.name);
        try cont.append('(');

        for (self.args.items, 0..) |arg, i| {
            if (i > 0)
                try cont.appendSlice(", ");

            try cont.appendSlice(arg);
        }

        try cont.append(')');

        try cont.append('\n');
    }
};

const SSAInstruction = union(enum) {
    intrinsic: SSAIntrinsic,

    fn toSSA(alloc: std.mem.Allocator, s: Statement, isMain: bool) error{OutOfMemory}!SSAInstruction {
        switch (s) {
            .ret => |ret| {
                if (isMain) {
                    var ins = SSAIntrinsic.init(alloc, "@exit");
                    try ins.args.append(ret.expr);
                    return SSAInstruction{
                        .intrinsic = ins,
                    };
                } else unreachable;
            },
            .func => |_| unreachable,
        }
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

    fn transformToSSA(alloc: std.mem.Allocator, sf: StatementFunc) error{OutOfMemory}!SSAFunction {
        var f = SSAFunction{
            .name = sf.name,
            .body = std.ArrayList(SSABlock).init(alloc),
            .returnType = sf.returnType,
        };

        try transformBodyToSSA(alloc, &f.body, sf.body, std.mem.eql(u8, f.name, "main"));

        return f;
    }

    fn transformBodyToSSA(alloc: std.mem.Allocator, body: *std.ArrayList(SSABlock), ss: Statements, isMain: bool) error{OutOfMemory}!void {
        var b = SSABlock{
            .name = "1",
            .body = std.ArrayList(SSAInstruction).init(alloc),
        };

        for (ss.items) |s| {
            const ins = try SSAInstruction.toSSA(alloc, s, isMain);
            try b.body.append(ins);
        }

        try body.append(b);
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

    pub fn toIR(self: *IR) error{OutOfMemory}!void {
        var it = self.program.funcs.iterator();
        var c = it.next();
        while (c != null) : (c = it.next()) {
            const f = try SSAFunction.transformToSSA(self.alloc, c.?.value_ptr.*);

            try self.ssa.funcs.put(f.name, f);
        }
    }

    pub fn toString(self: *@This(), alloc: std.mem.Allocator) error{OutOfMemory}!std.ArrayList(u8) {
        var cont = std.ArrayList(u8).init(alloc);

        try self.ssa.toString(&cont);

        return cont;
    }
};
