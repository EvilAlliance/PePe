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
};

const StatementFunc = struct {
    name: []const u8,
    // args: void,
    body: Statements,
};
const Statement = union(enum) {
    ret: StatementReturn,
    func: StatementFunc,
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

pub const Parser = struct {
    l: *Lexer,
    alloc: Allocator,
    program: *std.ArrayList(Statement),

    pub fn init(alloc: Allocator, l: *Lexer) Parser {
        var state = std.ArrayList(Statement).init(alloc);
        return Parser{
            .alloc = alloc,
            .l = l,
            .program = &state,
        };
    }

    pub fn parse(self: Parser) ?UnexpectedToken {
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

    fn parseGlobalScope(self: Parser) ?UnexpectedToken {
        const t = self.l.peek() orelse unreachable;
        if (t.type == TokenType.func) {
            const r = self.parseFunction();
            switch (r) {
                @TypeOf(r).ok => self.program.append(Statement{ .func = r.ok }) catch unreachable,
                @TypeOf(r).err => return r.err,
            }
            return null;
        }

        return expect(t, TokenType.any);
    }

    fn parseFunction(self: Parser) Result(StatementFunc, UnexpectedToken) {
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

        separator = self.l.pop();
        assert(separator != null);
        unexpected = expect(separator.?, TokenType.iden);
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
            .body = state.ok,
        });
    }

    fn parseFunctionBody(self: Parser) Result(Statements, UnexpectedToken) {
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

    fn parseReturn(self: Parser) Result(StatementReturn, UnexpectedToken) {
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

    fn parserExpression(self: Parser) Result(Expression, UnexpectedToken) {
        const r = Result(Expression, UnexpectedToken);

        const expr = self.l.pop();
        assert(expr != null);
        const unexpected = expect(expr.?, TokenType.numberLiteral);
        if (unexpected != null) return r.Err(unexpected.?);

        return r.Ok(expr.?.str);
    }
};
