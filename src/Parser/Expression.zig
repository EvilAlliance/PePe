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

pub const Expression = union(enum) {
    bin: struct {
        op: Token,
        left: *Expression,
        right: *Expression,
    },
    una: struct {
        op: Token,
        t: *Expression,
    },
    leaf: Token,

    pub fn parse(p: *Parser) error{OutOfMemory}!Result(*Expression, UnexpectedToken) {
        const r = Result(*Expression, UnexpectedToken);

        const leaf = @This(){ .leaf = p.l.pop() };
        var unexpected = Parser.expect(leaf.leaf, .numberLiteral);
        if (unexpected) |u| return r.Err(u);

        const semi = p.l.peek();

        const leftLeaf = try Util.dupe(p.alloc, leaf);
        if (semi.type == .semicolon) {
            return r.Ok(leftLeaf);
        } else if (semi.type == .symbol) {
            var symbol = p.l.pop();
            var addingSymbol = p.l.peek();
            while (addingSymbol.type == .symbol) : (addingSymbol = p.l.peek()) {
                _ = p.l.pop();
                symbol.str = symbol.loc.content[symbol.loc.i..addingSymbol.loc.i];
            }

            const potentailRightLeaf = @This(){ .leaf = p.l.pop() };
            unexpected = Parser.expect(leaf.leaf, .numberLiteral);
            if (unexpected) |u| return r.Err(u);

            const rightLeaf = try Util.dupe(p.alloc, potentailRightLeaf);
            var expr = try Util.dupe(p.alloc, @This(){
                .bin = .{
                    .op = symbol,
                    .left = leftLeaf,
                    .right = rightLeaf,
                },
            });
            var nextToken = p.l.peek();
            while (nextToken.type != .semicolon) : (nextToken = p.l.peek()) {
                var newSymbol = p.l.pop();
                addingSymbol = p.l.peek();
                while (addingSymbol.type == .symbol) : (addingSymbol = p.l.peek()) {
                    _ = p.l.pop();
                    newSymbol.str = symbol.loc.content[symbol.loc.i..addingSymbol.loc.i];
                }

                const l = @This(){ .leaf = p.l.pop() };
                unexpected = Parser.expect(leaf.leaf, .numberLiteral);
                if (unexpected) |u| return r.Err(u);

                const newLeaf = try Util.dupe(p.alloc, l);
                expr = try Util.dupe(p.alloc, @This(){
                    .bin = .{
                        .op = newSymbol,
                        .left = expr,
                        .right = newLeaf,
                    },
                });
            }

            return r.Ok(expr);
        } else {
            const unexpectedSymbol = Parser.expect(semi, .symbol);
            if (unexpectedSymbol) |u| return r.Err(u);

            const unexpectedSemi = Parser.expect(semi, .semicolon);
            if (unexpectedSemi) |u| return r.Err(u);
        }
        unreachable;
    }

    pub fn codeGen(self: @This(), g: tb.GraphBuilder, t: tb.DataType) *tb.Node {
        return switch (self) {
            .una => |_| unreachable,
            .bin => |b| {
                const left = b.left.codeGen(g, t);
                const right = b.right.codeGen(g, t);

                if (std.mem.eql(u8, b.op.str, "+")) {
                    return g.binopInt(tb.NodeType.ADD, left, right, tb.ArithmeticBehavior.NUW);
                } else if (std.mem.eql(u8, b.op.str, "-")) {
                    return g.binopInt(tb.NodeType.SUB, left, right, tb.ArithmeticBehavior.NUW);
                } else unreachable;
            },
            .leaf => |l| g.uint(t, std.fmt.parseUnsigned(u64, l.str, 10) catch unreachable),
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
                _ = u;
                unreachable;
            },
            .leaf => |l| {
                try cont.appendSlice(l.str);
            },
        }
    }
};
