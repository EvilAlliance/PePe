const std = @import("std");
const LEXER = @import("Lexer.zig");
const util = @import("Util.zig");

const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const TokenType = LEXER.TokenType;
const Token = LEXER.Token;
const Lexer = LEXER.Lexer;

const Result = util.Result;

const Expression = []const u8;

const StatementReturn = struct {
    expr: Expression,

    pub fn diplay(self: StatementReturn, d: u64) void {
        for (0..d) |_|
            std.debug.print("\t", .{});

        std.debug.print("Return: {s}\n", .{self.expr});
    }
};

const StatementFunc = struct {
    name: []const u8,
    // args: void,
    body: Statements,
    returnType: []const u8,

    pub fn diplay(self: StatementFunc, d: u64) void {
        for (0..d) |_|
            std.debug.print("\t", .{});

        std.debug.print("Function: \n", .{});

        for (0..d) |_|
            std.debug.print("\t", .{});
        std.debug.print("\t", .{});

        std.debug.print("Name: {s}\n", .{self.name});

        for (0..d) |_|
            std.debug.print("\t", .{});
        std.debug.print("\t", .{});

        std.debug.print("Return Type: {s}\n", .{self.returnType});

        for (0..d) |_|
            std.debug.print("\t", .{});
        std.debug.print("\t", .{});
        std.debug.print("Body: \n", .{});

        for (self.body.items) |statement| {
            statement.display(d + 2);
        }
    }
};
const Statement = union(enum) {
    ret: StatementReturn,
    func: StatementFunc,

    pub fn display(self: Statement, d: u64) void {
        switch (self) {
            .ret => |ret| ret.diplay(d),
            .func => |func| func.diplay(d),
        }
    }
};

const Statements = std.ArrayList(Statement);

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

const Program = struct {
    funcs: std.StringArrayHashMap(StatementFunc),
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

    pub fn parse(self: *Parser) ?UnexpectedToken {
        return self.parseGlobalScope();
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

    pub fn parseGlobalScope(self: *Parser) ?UnexpectedToken {
        const t = self.l.peek() orelse unreachable;
        if (t.type == TokenType.func) {
            const r = self.parseFunction();
            switch (r) {
                @TypeOf(r).ok => {
                    const func = self.alloc.create(StatementFunc) catch unreachable;
                    func.name = r.ok.name;
                    func.returnType = r.ok.returnType;
                    func.body = r.ok.body;
                    self.program.funcs.put(r.ok.name, func.*) catch unreachable;
                },
                @TypeOf(r).err => return r.err,
            }
            return null;
        }

        return expect(t, TokenType.any);
    }

    fn parseFunction(self: *Parser) Result(StatementFunc, UnexpectedToken) {
        const r = Result(StatementFunc, UnexpectedToken);

        var unexpected: ?UnexpectedToken = undefined;

        const func = self.l.peek();
        assert(func != null and func.?.type == TokenType.func);

        _ = self.l.pop();

        const name = self.l.pop();
        assert(name != null);

        unexpected = expect(name.?, TokenType.iden);
        if (unexpected != null) return r.Err(unexpected.?);

        var separator = self.l.pop();
        assert(separator != null);
        unexpected = expect(separator.?, TokenType.openParen);
        if (unexpected != null) return r.Err(unexpected.?);

        // TODO: ARGS

        separator = self.l.pop();
        assert(separator != null);
        unexpected = expect(separator.?, TokenType.closeParen);
        if (unexpected != null) return r.Err(unexpected.?);

        const t = self.l.pop();
        assert(t != null);
        unexpected = expect(t.?, TokenType.iden);
        if (unexpected != null) return r.Err(unexpected.?);

        separator = self.l.pop();
        assert(separator != null);
        unexpected = expect(separator.?, TokenType.openBrace);
        if (unexpected != null) return r.Err(unexpected.?);

        const state = self.parseFunctionBody();
        switch (state) {
            @TypeOf(state).ok => {},
            @TypeOf(state).err => return r.Err(state.err),
        }

        separator = self.l.pop();
        assert(separator != null);
        unexpected = expect(separator.?, TokenType.closeBrace);
        if (unexpected != null) return r.Err(unexpected.?);

        return r.Ok(StatementFunc{
            .name = name.?.str,
            // .args = void,
            .returnType = t.?.str,
            .body = state.ok,
        });
    }

    fn parseFunctionBody(self: *Parser) Result(Statements, UnexpectedToken) {
        const r = Result(Statements, UnexpectedToken);
        var unexpected: ?UnexpectedToken = undefined;
        var statements = Statements.init(self.alloc);

        var t = self.l.peek();
        assert(t != null);

        while (t.?.type != TokenType.closeBrace) {
            switch (t.?.type) {
                TokenType.ret => {
                    const state = self.parseReturn();
                    switch (state) {
                        @TypeOf(state).ok => statements.append(Statement{ .ret = state.ok }) catch unreachable,
                        @TypeOf(state).err => return r.Err(state.err),
                    }
                },
                TokenType.EOF => {
                    unexpected = expect(t.?, TokenType.closeBrace);
                    return r.Err(unexpected.?);
                },
                else => {
                    unexpected = expect(t.?, TokenType.any);
                    return r.Err(unexpected.?);
                },
            }
            t = self.l.peek();
        }

        return r.Ok(statements);
    }

    fn parseReturn(self: *Parser) Result(StatementReturn, UnexpectedToken) {
        const r = Result(StatementReturn, UnexpectedToken);

        const retToken = self.l.peek();
        assert(retToken != null and retToken.?.type == TokenType.ret);

        _ = self.l.pop();

        const result = self.parserExpression();
        switch (result) {
            @TypeOf(result).err => return r.Err(result.err),
            @TypeOf(result).ok => {},
        }
        const expr = result.ok;
        const ret = StatementReturn{ .expr = expr };

        const separator = self.l.pop();
        assert(separator != null);
        const unexpected = expect(separator.?, TokenType.semicolon);
        if (unexpected != null) return r.Err(unexpected.?);

        return r.Ok(ret);
    }

    fn parserExpression(self: *Parser) Result(Expression, UnexpectedToken) {
        const r = Result(Expression, UnexpectedToken);

        const expr = self.l.pop();
        assert(expr != null);
        const unexpected = expect(expr.?, TokenType.numberLiteral);
        if (unexpected != null) return r.Err(unexpected.?);

        return r.Ok(expr.?.str);
    }
};
