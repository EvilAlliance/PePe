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

    pub fn parse(p: *Parser) Result(*Expression, UnexpectedToken) {
        const r = Result(*Expression, UnexpectedToken);

        const leftLeaf = @This(){ .leaf = p.l.pop() };
        const unexpected = Parser.expect(leftLeaf.leaf, .numberLiteral);
        if (unexpected) |u| return r.Err(u);

        const semi = p.l.peek();

        if (semi.type == .semicolon) {
            const expr = p.alloc.create(Expression) catch {
                std.log.err("Out of memory", .{});
                std.process.exit(1);
            };

            expr.* = leftLeaf;

            return r.Ok(expr);
        } else if (semi.type == .symbol) {
            var addingSymbol = p.l.pop();
            var symbol = addingSymbol;
            addingSymbol = p.l.peek();
            while (addingSymbol.type == .symbol) : (addingSymbol = p.l.peek()) {
                _ = p.l.pop();
                symbol.str = symbol.loc.content[symbol.loc.i..addingSymbol.loc.i];
            }

            const rightLeaf = parse(p);

            switch (rightLeaf) {
                .err => return rightLeaf,
                .ok => {},
            }

            const expr = p.alloc.create(Expression) catch {
                std.log.err("Out of memory", .{});
                std.process.exit(1);
            };

            expr.* = .{
                .bin = .{
                    .op = symbol,
                    .left = p.alloc.create(Expression) catch {
                        std.log.err("Out of memory", .{});
                        std.process.exit(1);
                    },
                    .right = rightLeaf.ok,
                },
            };
            expr.bin.left.* = leftLeaf;

            return r.Ok(expr);
        } else {
            const unexpectedSymbol = Parser.expect(semi, .symbol);
            if (unexpectedSymbol) |u| return r.Err(u);

            const unexpectedSemi = Parser.expect(semi, .semicolon);
            if (unexpectedSemi) |u| return r.Err(u);
        }
        unreachable;
    }

    pub fn codeGen(self: @This(), g: tb.GraphBuilder, f: IR.Function) *tb.Node {
        return switch (self) {
            .una => |_| unreachable,
            .bin => |b| {
                const left = b.left.codeGen(g, f);
                const right = b.right.codeGen(g, f);
                const op = g.binopInt(tb.NodeType.ADD, left, right, tb.ArithmeticBehavior.NUW);
                return op;
            },
            .leaf => |l| g.uint(getType(f.returnType), std.fmt.parseUnsigned(u64, l.str, 10) catch unreachable),
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
