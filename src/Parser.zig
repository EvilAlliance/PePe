const std = @import("std");
const LEXER = @import("Lexer.zig");
const util = @import("Util.zig");
const gen = @import("General.zig");

const message = gen.message;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const TokenType = LEXER.TokenType;
const Token = LEXER.Token;
const Lexer = LEXER.Lexer;

const Result = util.Result;

pub const Expression = []const u8;

const StatementReturn = struct {
    expr: Expression,

    fn parse(p: *Parser) Result(StatementReturn, UnexpectedToken) {
        const r = Result(StatementReturn, UnexpectedToken);

        const retToken = p.l.peek();
        assert(retToken != null and retToken.?.type == TokenType.ret);

        _ = p.l.pop();

        const result = p.parserExpression();
        switch (result) {
            .err => return r.Err(result.err),
            .ok => {},
        }
        const expr = result.ok;
        const ret = StatementReturn{ .expr = expr };

        const separator = p.l.pop();
        assert(separator != null);
        const unexpected = Parser.expect(separator.?, TokenType.semicolon);
        if (unexpected != null) return r.Err(unexpected.?);

        return r.Ok(ret);
    }

    pub fn toString(self: StatementReturn, cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
        for (0..d) |_|
            try cont.append(' ');

        try cont.appendSlice("Return: ");
        try cont.appendSlice(self.expr);
        try cont.append('\n');
    }
};

pub const StatementFunc = struct {
    name: []const u8,
    //args: void,
    body: Statements,
    returnType: []const u8,

    pub fn parse(p: *Parser) error{OutOfMemory}!Result(@This(), UnexpectedToken) {
        const r = Result(@This(), UnexpectedToken);

        var unexpected: ?UnexpectedToken = undefined;

        const func = p.l.peek();
        assert(func != null and func.?.type == TokenType.func);

        _ = p.l.pop();

        const name = p.l.pop();
        assert(name != null);

        unexpected = Parser.expect(name.?, TokenType.iden);
        if (unexpected != null) return r.Err(unexpected.?);

        var separator = p.l.pop();
        assert(separator != null);
        unexpected = Parser.expect(separator.?, TokenType.openParen);
        if (unexpected != null) return r.Err(unexpected.?);

        // TODO: ARGS

        separator = p.l.pop();
        assert(separator != null);
        unexpected = Parser.expect(separator.?, TokenType.closeParen);
        if (unexpected != null) return r.Err(unexpected.?);

        const t = p.l.pop();
        assert(t != null);
        unexpected = Parser.expect(t.?, TokenType.iden);
        if (unexpected != null) return r.Err(unexpected.?);

        separator = p.l.pop();
        assert(separator != null);
        unexpected = Parser.expect(separator.?, TokenType.openBrace);
        if (unexpected != null) return r.Err(unexpected.?);

        const state = try StatementFunc.parseBody(p);
        switch (state) {
            .ok => {},
            .err => return r.Err(state.err),
        }

        separator = p.l.pop();
        assert(separator != null);
        unexpected = Parser.expect(separator.?, TokenType.closeBrace);
        if (unexpected != null) return r.Err(unexpected.?);

        return r.Ok(StatementFunc{
            .name = name.?.str,
            // .args = void,
            .returnType = t.?.str,
            .body = state.ok,
        });
    }

    fn parseBody(p: *Parser) error{OutOfMemory}!Result(Statements, UnexpectedToken) {
        const r = Result(Statements, UnexpectedToken);
        var statements = Statements.init(p.alloc);

        var t = p.l.peek();

        while (t != null and t.?.type != TokenType.closeBrace) : (t = p.l.peek()) {
            const state = Statement.parse(p, t.?);

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
        try cont.appendSlice(self.returnType);
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
        std.debug.print("Expected: {},\nFound: {},\nIn:{s}: {}:{}\n", .{
            self.expected,
            self.found,
            self.path,
            self.loc.row,
            self.loc.col,
        });
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
        const t = self.l.peek() orelse unreachable;
        if (t.type == TokenType.func) {
            const r = try StatementFunc.parse(self);
            switch (r) {
                .ok => {
                    try self.program.funcs.put(r.ok.name, r.ok);
                },
                .err => return r.err,
            }
            return null;
        }

        return expect(t, TokenType.any);
    }

    fn parserExpression(self: *Parser) Result(Expression, UnexpectedToken) {
        const r = Result(Expression, UnexpectedToken);

        const expr = self.l.pop();
        assert(expr != null);
        const unexpected = expect(expr.?, TokenType.numberLiteral);
        if (unexpected != null) return r.Err(unexpected.?);

        return r.Ok(expr.?.str);
    }

    pub fn toString(self: *Parser, alloc: std.mem.Allocator) error{OutOfMemory}!std.ArrayList(u8) {
        var cont = std.ArrayList(u8).init(alloc);
        try self.program.toString(&cont);
        return cont;
    }
};
