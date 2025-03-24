const std = @import("std");

const Parser = @import("Parser.zig");
const UnexpectedToken = Parser.UnexpectedToken;

const Lexer = @import("../Lexer/Lexer.zig");
const Token = Lexer.Token;

const Util = @import("../Util.zig");
const Result = Util.Result;

const IR = @import("../IR/IR.zig");

const tb = @import("../libs/tb/tb.zig");

const tbHelper = @import("../TBHelper.zig");
const getType = tbHelper.getType;

pub const Operand = std.StaticStringMap(u8).initComptime(.{
    .{ "^", 0 },
    .{ "%", 1 },
    .{ "*", 1 },
    .{ "/", 1 },
    .{ "+", 2 },
    .{ "-", 2 },
});

pub const Binary = std.StaticStringMap(*const fn (g: tb.GraphBuilder, left: *tb.Node, right: *tb.Node, usigned: bool) *tb.Node).initComptime(.{
    .{ "^", &BinaryFunction.power },
    .{ "%", &BinaryFunction.mod },
    .{ "*", &BinaryFunction.multiply },
    .{ "/", &BinaryFunction.division },
    .{ "+", &BinaryFunction.plus },
    .{ "-", &BinaryFunction.minus },
});

// For overflow, underflow execption and division and mod that requiere different node types.
const BinaryFunction = struct {
    pub fn minus(g: tb.GraphBuilder, left: *tb.Node, right: *tb.Node, unsigned: bool) *tb.Node {
        _ = unsigned;
        return g.binopInt(tb.NodeType.SUB, left, right, tb.ArithmeticBehavior.NONE);
    }
    pub fn plus(g: tb.GraphBuilder, left: *tb.Node, right: *tb.Node, unsigned: bool) *tb.Node {
        _ = unsigned;
        return g.binopInt(tb.NodeType.ADD, left, right, tb.ArithmeticBehavior.NONE);
    }
    pub fn multiply(g: tb.GraphBuilder, left: *tb.Node, right: *tb.Node, unsigned: bool) *tb.Node {
        _ = unsigned;
        return g.binopInt(tb.NodeType.MUL, left, right, tb.ArithmeticBehavior.NONE);
    }
    pub fn division(g: tb.GraphBuilder, left: *tb.Node, right: *tb.Node, unsigned: bool) *tb.Node {
        _ = unsigned;
        return g.binopInt(tb.NodeType.UDIV, left, right, tb.ArithmeticBehavior.NONE);
    }
    pub fn mod(g: tb.GraphBuilder, left: *tb.Node, right: *tb.Node, unsigned: bool) *tb.Node {
        _ = unsigned;
        return g.binopInt(tb.NodeType.UMOD, left, right, tb.ArithmeticBehavior.NONE);
    }
    pub fn power(g: tb.GraphBuilder, base: *tb.Node, exp: *tb.Node, unsigned: bool) *tb.Node {
        std.log.warn("Unstable with optimizer", .{});

        _ = unsigned;

        const condAddr = g.local(1, 1);
        g.store(0, false, condAddr, exp, 1, false);

        const resultAddr = g.local(1, 1);
        g.store(0, false, resultAddr, g.uint(base.dt, 1), 1, false);

        const exit = g.labelMake();
        const header = g.loop();
        const loop = g.labelClone(header);

        {
            var paths: [2]*tb.Node = undefined;

            const n = g.load(0, false, exp.dt, condAddr, 1, false);
            // const zero = g.uint(n.dt, 0);
            // const cond = g.cmp(tb.NodeType.CMP_NE, n, zero);

            g.@"if"(n, &paths);

            _ = g.labelSet(paths[1]);
            g.br(exit);
            g.labelKill(paths[1]);

            _ = g.labelSet(paths[0]);
            const result = g.load(0, false, exp.dt, resultAddr, 1, false);
            const newResult = g.binopInt(tb.NodeType.MUL, result, base, tb.ArithmeticBehavior.NONE);
            g.store(0, false, resultAddr, newResult, 1, false);

            const newValue = g.binopInt(tb.NodeType.SUB, n, g.uint(tb.typeI8(), 1), tb.ArithmeticBehavior.NONE);
            g.store(0, false, condAddr, newValue, 1, false);

            g.br(loop);
            g.labelKill(paths[0]);
        }

        g.labelKill(loop);
        g.labelKill(header);

        _ = g.labelSet(exit);

        const result = g.load(0, false, base.dt, resultAddr, 1, false);

        return result;
    }
};

pub const Unary = std.StaticStringMap(*const fn (g: tb.GraphBuilder, e: *tb.Node, usigned: bool) *tb.Node).initComptime(.{
    .{ "-", &UnaryFunction.neg },
});

const UnaryFunction = struct {
    pub fn neg(g: tb.GraphBuilder, e: *tb.Node, unsigned: bool) *tb.Node {
        _ = unsigned;
        return g.neg(e);
    }
};

//https://en.cppreference.com/w/c/language/operator_precedence

pub const Expression = union(enum) {
    var depth: u64 = 0;

    bin: struct {
        op: Token,
        left: *Expression,
        right: *Expression,
    },
    una: struct {
        op: Token,
        e: *Expression,
    },
    leaf: Token,
    paren: *Expression,
    variable: Token,

    fn makeLeaf(alloc: std.mem.Allocator, t: Token) std.mem.Allocator.Error!*@This() {
        return Util.dupe(alloc, @This(){ .leaf = t });
    }

    fn makeVar(alloc: std.mem.Allocator, t: Token) std.mem.Allocator.Error!*@This() {
        return Util.dupe(alloc, @This(){ .variable = t });
    }

    fn makeParen(alloc: std.mem.Allocator, t: *@This()) std.mem.Allocator.Error!*@This() {
        return Util.dupe(alloc, @This(){ .paren = t });
    }

    fn makeUnary(alloc: std.mem.Allocator, op: Token, expr: *@This()) std.mem.Allocator.Error!*@This() {
        return Util.dupe(
            alloc,
            @This(){
                .una = .{
                    .op = op,
                    .e = expr,
                },
            },
        );
    }

    fn makeBinary(alloc: std.mem.Allocator, op: Token, left: *@This(), right: *@This()) std.mem.Allocator.Error!*@This() {
        switch (left.*) {
            else => {
                return Util.dupe(
                    alloc,
                    @This(){
                        .bin = .{
                            .op = op,
                            .left = left,
                            .right = right,
                        },
                    },
                );
            },
            .bin => {
                if (Operand.get(op.str).? >= Operand.get(left.bin.op.str).?) {
                    return Util.dupe(
                        alloc,
                        @This(){
                            .bin = .{
                                .op = op,
                                .left = left,
                                .right = right,
                            },
                        },
                    );
                } else {
                    const leftRight = left.bin.right;
                    const newExpr = try Util.dupe(
                        alloc,
                        @This(){
                            .bin = .{
                                .op = op,
                                .left = leftRight,
                                .right = right,
                            },
                        },
                    );

                    left.bin.right = newExpr;
                    return left;
                }
            },
        }
    }

    fn parseTerm(p: *Parser) std.mem.Allocator.Error!Result(*@This(), UnexpectedToken) {
        const r = Result(*@This(), UnexpectedToken);

        var nextToken = p.l.peek();

        if (nextToken.type == .openParen) {
            depth += 1;
            _ = p.l.pop();

            const expr = switch (try parse(p)) {
                .ok => |ok| ok,
                .err => |err| return r.Err(err),
            };

            if (p.l.pop().type != .closeParen) unreachable;

            if (depth == 0) unreachable;
            depth -= 1;

            return r.Ok(try makeParen(p.alloc, expr));
        } else if (nextToken.type == .symbol) {
            const op = p.l.pop();
            nextToken = p.l.peek();
            if (nextToken.type == .openParen) {
                depth += 1;
                _ = p.l.pop();

                const expr = switch (try parse(p)) {
                    .ok => |ok| ok,
                    .err => |err| return r.Err(err),
                };

                if (p.l.pop().type != .closeParen) unreachable;

                if (depth == 0) unreachable;
                depth -= 1;

                return r.Ok(try makeUnary(p.alloc, op, try makeParen(p.alloc, expr)));
            } else if (nextToken.type == .symbol) {
                const expr = switch (try parseTerm(p)) {
                    .ok => |ok| ok,
                    .err => |err| return r.Err(err),
                };

                return r.Ok(try makeUnary(p.alloc, op, expr));
            } else if (nextToken.type == .numberLiteral) {
                return r.Ok(try makeUnary(p.alloc, op, try makeLeaf(p.alloc, p.l.pop())));
            }
        } else if (nextToken.type == .numberLiteral) {
            return r.Ok(try makeLeaf(p.alloc, p.l.pop()));
        } else if (nextToken.type == .iden) {
            return r.Ok(try makeVar(p.alloc, p.l.pop()));
        }
        unreachable;
    }

    pub fn parse(p: *Parser) std.mem.Allocator.Error!Result(*@This(), UnexpectedToken) {
        const r = Result(*@This(), UnexpectedToken);
        var nextToken = p.l.peek();
        if (nextToken.type == .semicolon) unreachable;

        var expr = switch (try parseTerm(p)) {
            .ok => |ok| ok,
            .err => |err| return r.Err(err),
        };

        nextToken = p.l.peek();

        while (nextToken.type != .semicolon and nextToken.type != .closeParen) : (nextToken = p.l.peek()) {
            const op = p.l.pop();
            if (op.type != .symbol) unreachable;

            const right = switch (try parseTerm(p)) {
                .ok => |ok| ok,
                .err => |err| return r.Err(err),
            };

            expr = try makeBinary(p.alloc, op, expr, right);
        }

        return r.Ok(expr);
    }

    pub fn codeGen(self: @This(), g: tb.GraphBuilder, scope: *std.StringHashMap(*tb.Node), ty: Parser.Primitive, t: tb.DataType) *tb.Node {
        return switch (self) {
            .una => |u| Unary.get(u.op.str).?(g, u.e.codeGen(g, scope, ty, t), true),
            .paren => |p| return p.codeGen(g, scope, ty, t),
            .bin => |b| {
                const left = b.left.codeGen(g, scope, ty, t);
                const right = b.right.codeGen(g, scope, ty, t);
                return Binary.get(b.op.str).?(g, left, right, true);
            },
            .leaf => |l| {
                return g.uint(t, std.fmt.parseUnsigned(u64, l.str, 10) catch unreachable);
            },
            .variable => |v| {
                const addr = scope.get(v.str).?;

                return g.load(0, false, t, addr, ty.size / 8, false);
            },
        };
    }

    pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
        switch (self) {
            .bin => |b| {
                try cont.append('(');
                try b.left.toString(cont, d);
                try cont.append(' ');
                try cont.appendSlice(b.op.str);
                try cont.append(' ');
                try b.right.toString(cont, d);
                try cont.append(')');
            },
            .una => |u| {
                try cont.append('(');
                try cont.appendSlice(u.op.str);
                try u.e.toString(cont, d);
                try cont.append(')');
            },
            .leaf => |l| {
                try cont.appendSlice(l.str);
            },
            .paren => |p| {
                try p.toString(cont, d);
            },
            .variable => |v| {
                try cont.appendSlice(v.str);
            },
        }
    }
};
