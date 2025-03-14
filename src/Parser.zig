const std = @import("std");
const LEXER = @import("Lexer.zig");
const util = @import("Util.zig");
const gen = @import("General.zig");
const tb = @import("./libs/tb/tb.zig");
const tbHelper = @import("TBHelper.zig");
const SSA = @import("IR.zig");

const getType = tbHelper.getType;

const message = gen.message;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const TokenType = LEXER.TokenType;
const Token = LEXER.Token;
const Lexer = LEXER.Lexer;
const Location = LEXER.Location;

const Result = util.Result;

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

    fn parser(p: *Parser) Result(*Expression, UnexpectedToken) {
        const r = Result(*Expression, UnexpectedToken);

        const leftLeaf = @This(){ .leaf = p.l.pop() };
        const unexpected = Parser.expect(leftLeaf.leaf, TokenType.numberLiteral);
        if (unexpected != null) return r.Err(unexpected.?);

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

            const rightLeaf = parser(p);

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
            const unexpectedSymbol = Parser.expect(semi, TokenType.symbol);
            if (unexpectedSymbol != null) return r.Err(unexpectedSymbol.?);

            const unexpectedSemi = Parser.expect(semi, TokenType.semicolon);
            if (unexpectedSemi != null) return r.Err(unexpectedSemi.?);
        }
        unreachable;
    }

    pub fn codeGen(self: @This(), g: tb.GraphBuilder, f: SSA.SSAFunction) *tb.Node {
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

pub const Primitive = struct {
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

    pub fn toString(self: @This(), cont: *std.ArrayList(u8)) error{OutOfMemory}!void {
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
};

const StatementReturn = struct {
    expr: *Expression,
    loc: Location,

    fn parse(p: *Parser) Result(StatementReturn, UnexpectedToken) {
        const r = Result(StatementReturn, UnexpectedToken);

        const retToken = p.l.peek();
        assert(retToken.type == TokenType.ret);
        const retLoc = retToken.loc;

        _ = p.l.pop();

        const result = Expression.parser(p);
        switch (result) {
            .err => return r.Err(result.err),
            .ok => {},
        }
        const expr = result.ok;
        const ret = StatementReturn{
            .expr = expr,
            .loc = retLoc,
        };

        const separator = p.l.pop();
        const unexpected = Parser.expect(separator, TokenType.semicolon);
        if (unexpected != null) return r.Err(unexpected.?);

        return r.Ok(ret);
    }

    pub fn toString(self: StatementReturn, cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
        for (0..d) |_|
            try cont.append(' ');

        try cont.appendSlice("Return: ");
        try self.expr.toString(cont, d);
        try cont.append('\n');
    }
};

pub const StatementFunc = struct {
    name: []const u8,
    //args: void,
    body: Statements,
    returnType: Primitive,
    loc: Location,

    pub fn parse(p: *Parser) error{OutOfMemory}!Result(@This(), UnexpectedToken) {
        const r = Result(@This(), UnexpectedToken);

        var unexpected: ?UnexpectedToken = undefined;

        const func = p.l.peek();
        assert(func.type == TokenType.func);

        _ = p.l.pop();

        const name = p.l.pop();
        unexpected = Parser.expect(name, TokenType.iden);
        if (unexpected != null) return r.Err(unexpected.?);
        const funcLoc = name.loc;

        var separator = p.l.pop();
        unexpected = Parser.expect(separator, TokenType.openParen);
        if (unexpected != null) return r.Err(unexpected.?);

        // TODO: ARGS

        separator = p.l.pop();
        unexpected = Parser.expect(separator, TokenType.closeParen);
        if (unexpected != null) return r.Err(unexpected.?);

        const ret = p.l.pop();
        unexpected = Parser.expect(ret, TokenType.iden);
        if (unexpected != null) return r.Err(unexpected.?);

        separator = p.l.pop();
        unexpected = Parser.expect(separator, TokenType.openBrace);
        if (unexpected != null) return r.Err(unexpected.?);

        const state = try StatementFunc.parseBody(p);
        switch (state) {
            .ok => {},
            .err => return r.Err(state.err),
        }

        separator = p.l.pop();
        unexpected = Parser.expect(separator, TokenType.closeBrace);
        if (unexpected != null) return r.Err(unexpected.?);

        return r.Ok(StatementFunc{
            .name = name.str,
            // .args = void,
            .returnType = Primitive.getType(ret.str),
            .body = state.ok,
            .loc = funcLoc,
        });
    }

    fn parseBody(p: *Parser) error{OutOfMemory}!Result(Statements, UnexpectedToken) {
        const r = Result(Statements, UnexpectedToken);
        var statements = Statements.init(p.alloc);

        var t = p.l.peek();

        while (t.type != TokenType.closeBrace) : (t = p.l.peek()) {
            const state = Statement.parse(p, t);

            switch (state) {
                .ok => try statements.append(state.ok),
                .err => return r.Err(state.err),
            }
        }

        return r.Ok(statements);
    }

    pub fn toString(self: StatementFunc, cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
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
        try self.returnType.toString(cont);
        try cont.append('\n');

        for (0..d + 2) |_|
            try cont.append(' ');

        try cont.appendSlice("Body:\n");

        for (self.body.items) |statement| {
            try statement.toString(cont, d + 4);
        }
    }
};
pub const Statement = union(enum) {
    ret: StatementReturn,
    func: StatementFunc,

    fn parse(p: *Parser, t: Token) Result(Statement, UnexpectedToken) {
        const r = Result(Statement, UnexpectedToken);
        switch (t.type) {
            TokenType.ret => {
                const state = StatementReturn.parse(p);
                switch (state) {
                    .ok => return r.Ok(Statement{ .ret = state.ok }),
                    .err => return r.Err(state.err),
                }
            },
            TokenType.EOF => {
                const unexpected = Parser.expect(t, TokenType.closeBrace);
                return r.Err(unexpected.?);
            },
            else => {
                const unexpected = Parser.expect(t, TokenType.any);
                return r.Err(unexpected.?);
            },
        }
    }

    pub fn toString(self: Statement, cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
        switch (self) {
            .ret => |ret| try ret.toString(cont, d),
            .func => |func| try func.toString(cont, d),
        }
    }
};

pub const Statements = std.ArrayList(Statement);

const UnexpectedToken = struct {
    expected: TokenType,
    found: TokenType,
    path: []const u8,
    absPath: []const u8,
    loc: LEXER.Location,

    pub fn display(self: UnexpectedToken) void {
        std.log.err("Expected: {},\nFound: {},\nIn:{s}:{}:{}\n", .{
            self.expected,
            self.found,
            self.path,
            self.loc.row,
            self.loc.col,
        });
        self.loc.print(std.log.err);
    }
};

pub const Program = struct {
    funcs: std.StringArrayHashMap(StatementFunc),

    pub fn toString(self: @This(), cont: *std.ArrayList(u8)) error{OutOfMemory}!void {
        var it = self.funcs.iterator();

        var state = it.next();
        while (state != null) : (state = it.next()) {
            try state.?.value_ptr.toString(cont, 0);
        }
    }
};

pub const Parser = struct {
    l: *Lexer,
    alloc: Allocator,
    program: Program,

    pub fn init(alloc: Allocator, l: *Lexer) Parser {
        return Parser{
            .alloc = alloc,
            .l = l,
            .program = Program{
                .funcs = std.StringArrayHashMap(StatementFunc).init(alloc),
            },
        };
    }

    pub fn parse(self: *Parser) error{OutOfMemory}!?UnexpectedToken {
        return try self.parseGlobalScope();
    }

    fn expect(token: Token, t: TokenType) ?UnexpectedToken {
        if (token.type != t)
            return UnexpectedToken{
                .expected = t,
                .found = token.type,
                .loc = token.loc,
                .path = token.path,
                .absPath = token.absPath,
            };

        return null;
    }

    pub fn parseGlobalScope(self: *Parser) error{OutOfMemory}!?UnexpectedToken {
        var t = self.l.peek();
        if (t.type == TokenType.EOF) return null;
        while (t.type != TokenType.EOF) : (t = self.l.peek()) {
            if (t.type == TokenType.func) {
                const r = try StatementFunc.parse(self);
                switch (r) {
                    .ok => try self.program.funcs.put(r.ok.name, r.ok),
                    .err => return r.err,
                }
                return null;
            }
        }

        return expect(t, TokenType.any);
    }

    pub fn toString(self: *Parser, alloc: std.mem.Allocator) error{OutOfMemory}!std.ArrayList(u8) {
        var cont = std.ArrayList(u8).init(alloc);
        try self.program.toString(&cont);
        return cont;
    }
};
