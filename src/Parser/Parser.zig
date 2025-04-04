const std = @import("std");
const Logger = @import("../Logger.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const Util = @import("../Util.zig");
const gen = @import("../General.zig");
const tb = @import("../libs/tb/tb.zig");
const tbHelper = @import("../TBHelper.zig");

const getType = tbHelper.getType;

const message = gen.message;

const Lexer = @import("../Lexer/Lexer.zig");

pub const Node = @import("Node.zig");
pub const UnexpectedToken = @import("UnexpectedToken.zig");
pub const nl = @import("./NodeListUtil.zig");
pub const Expression = @import("Expression.zig");
pub const Ast = @import("Ast.zig");

l: Lexer,
alloc: Allocator,
source: [:0]const u8,

functions: Ast.Program,
nodeList: Ast.NodeList,
temp: Ast.NodeList,

errors: std.ArrayList(UnexpectedToken),

depth: usize = 0,

pub fn init(alloc: Allocator, path: []const u8) ?@This() {
    const absPath, const source = Util.readEntireFile(alloc, path) catch |err| {
        switch (err) {
            error.couldNotOpenFile => Logger.log.err("Could not open file: {s}\n", .{path}),
            error.couldNotReadFile => Logger.log.err("Could not read file: {s}]n", .{path}),
            error.couldNotGetFileSize => Logger.log.err("Could not get file ({s}) size\n", .{path}),
            error.couldNotGetAbsolutePath => Logger.log.err("Could not get absolute path of file ({s})\n", .{path}),
        }
        return null;
    };

    return @This(){
        .alloc = alloc,
        .l = Lexer.init(alloc, path, absPath, source),
        .source = source,

        .functions = Ast.Program.init(alloc),
        .nodeList = Ast.NodeList.init(alloc),
        .temp = Ast.NodeList.init(alloc),

        .errors = std.ArrayList(UnexpectedToken).init(alloc),
    };
}

pub fn deinit(self: *@This()) void {
    for (self.errors.items) |value| {
        value.deinit();
    }

    self.errors.deinit();
    self.temp.deinit();
}

pub fn expect(self: *@This(), token: Lexer.Token, t: []const Lexer.TokenType) std.mem.Allocator.Error!bool {
    const ex = try self.alloc.dupe(Lexer.TokenType, t);
    const is = Util.listContains(Lexer.TokenType, ex, token.tag);
    if (!is) {
        try self.errors.append(UnexpectedToken{
            .expected = ex,
            .found = token.tag,
            .loc = token.loc,
            .alloc = self.alloc,
        });
    }

    return is;
}

fn peek(self: *@This()) Lexer.Token {
    return self.l.peek();
}

fn popIf(self: *@This(), t: Lexer.TokenType) ?Lexer.Token {
    if (self.l.peek().tag != t) return null;
    return self.l.pop();
}

fn pop(self: *@This()) Lexer.Token {
    return self.l.pop();
}

pub fn parse(self: *@This()) (std.mem.Allocator.Error)!Ast {
    self.parseRoot() catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {},
    };

    return Ast.init(self.alloc, self.functions, self.nodeList, self.source);
}

fn parseRoot(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!void {
    const top = self.temp.items.len;
    defer self.temp.shrinkRetainingCapacity(top);

    try self.temp.insert(0, .{ .tag = .root, .token = null, .data = .{ 1, 0 } });

    var t = self.peek();
    while (t.tag != .EOF) : (t = self.l.peek()) {
        if (!try self.expect(t, &.{.func})) return error.UnexpectedToken;

        switch (t.tag) {
            .func => try self.parseFuncDelc(),
            // .let => unreachable,
            else => unreachable,
        }
    }

    self.temp.items[0].data[1] = self.temp.items.len;

    try self.nodeList.appendSlice(self.temp.items);
}

fn parseFuncDelc(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!void {
    _ = self.popIf(.func) orelse unreachable;

    if (!try self.expect(self.peek(), &.{.iden})) return error.UnexpectedToken;
    const mainToken = self.pop();

    const nodeIndex = try nl.addNode(&self.temp, .{
        .token = mainToken,
        .tag = .funcDecl,
        .data = .{ 0, 0 },
    });

    if (!try self.expect(self.peek(), &.{.openParen})) return error.UnexpectedToken;
    {
        const p = try self.parseFuncProto();
        self.temp.items[nodeIndex].data[0] = p;
    }

    if (self.peek().tag != .openBrace) {
        self.temp.items[nodeIndex].data[1] = self.temp.items.len;
        try self.parseStatement();
    } else {
        const p = try self.parseScope();
        self.temp.items[nodeIndex].data[1] = p;
    }

    try self.functions.put(mainToken.getText(self.source), nodeIndex);
}

fn parseFuncProto(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
    const nodeIndex = try nl.addNode(&self.temp, .{
        .token = null,
        .tag = .funcProto,
        .data = .{ 0, 0 },
    });

    if (!try self.expect(self.peek(), &.{.openParen})) return error.UnexpectedToken;
    _ = self.pop();
    // TODO: Parse arguments
    if (!try self.expect(self.peek(), &.{.closeParen})) return error.UnexpectedToken;
    _ = self.pop();

    {
        const p = try self.parseType();
        self.temp.items[nodeIndex].data[1] = p;
    }

    return nodeIndex;
}

fn parseType(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
    if (!try self.expect(self.peek(), &.{ .unsigned8, .unsigned16, .unsigned32, .unsigned64, .signed8, .signed16, .signed32, .signed64 })) return error.UnexpectedToken;
    const mainToken = self.pop();

    const nodeIndex = try nl.addNode(&self.temp, .{
        .token = mainToken,
        .tag = .type,
        .data = .{ 0, 0 },
    });

    return nodeIndex;
}

fn parseScope(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
    _ = self.popIf(.openBrace) orelse unreachable;

    const nodeIndex = try nl.addNode(&self.temp, .{
        .token = null,
        .tag = .scope,
        .data = .{ 0, 0 },
    });

    self.temp.items[nodeIndex].data[0] = nodeIndex + 1;

    while (self.peek().tag != .closeBrace) {
        const top = self.temp.items.len;
        self.parseStatement() catch |err| switch (err) {
            error.UnexpectedToken => {
                self.temp.shrinkRetainingCapacity(top);
                while (self.peek().tag != .semicolon) : (_ = self.pop()) {}
                _ = self.pop();
            },
            error.OutOfMemory => return error.OutOfMemory,
        };
    }

    if (!try self.expect(self.peek(), &.{.closeBrace})) return error.UnexpectedToken;
    _ = self.pop();

    self.temp.items[nodeIndex].data[1] = self.temp.items.len;

    return nodeIndex;
}

fn parseStatement(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!void {
    if (!try self.expect(self.peek(), &.{ .ret, .iden })) return error.UnexpectedToken;

    const nodeIndex = switch (self.peek().tag) {
        .ret => try self.parseReturn(),
        .iden => try self.parseVariableDecl(),
        else => unreachable,
    };

    if (!try self.expect(self.peek(), &.{.semicolon})) return error.UnexpectedToken;
    _ = self.pop();

    self.temp.items[nodeIndex].data[1] = self.temp.items.len;
    return;
}

fn parseVariableDecl(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
    const name = self.popIf(.iden) orelse unreachable;

    if (!try self.expect(self.peek(), &.{.colon})) return error.UnexpectedToken;

    const variable = try nl.addNode(&self.temp, .{
        .tag = Node.Tag.variable,
        .token = name,
        .data = .{ 0, 0 },
    });

    {
        const p, const v = try self.parseVariableProto();
        self.temp.items[variable].tag = v;
        self.temp.items[variable].data[0] = p;
    }

    return variable;
}

fn parseVariableProto(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!struct { usize, Node.Tag } {
    var constant: Node.Tag = .variable;

    const proto = try nl.addNode(&self.temp, .{
        .tag = .VarProto,
        .token = null,
        .data = .{ 0, 0 },
    });

    if (!try self.expect(self.peek(), &.{.colon})) return error.UnexpectedToken;
    _ = self.pop();

    const possibleType = self.peek();

    if (possibleType.tag != .colon and possibleType.tag != .equal) {
        const p = try self.parseType();
        self.temp.items[proto].data[0] = p;
    }

    if (!try self.expect(self.peek(), &.{ .colon, .equal })) return error.UnexpectedToken;

    const possibleExpr = self.peek();

    if (possibleExpr.tag == .colon or possibleExpr.tag == .equal) {
        if (self.pop().tag == .colon)
            constant = .constant;

        const p = try self.parseExpression();
        self.temp.items[proto].data[1] = p;
    }

    if (!try self.expect(self.peek(), &.{.semicolon})) return error.UnexpectedToken;

    return .{ proto, constant };
}

fn parseReturn(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
    const ret = self.popIf(.ret) orelse unreachable;

    const nodeIndex = try nl.addNode(&self.temp, .{
        .tag = .ret,
        .token = ret,
        .data = .{ 0, 0 },
    });

    std.debug.assert(self.depth == 0);
    const exp = try self.parseExpression();
    std.debug.assert(self.depth == 0);

    self.temp.items[nodeIndex].data[0] = exp;

    if (!try self.expect(self.peek(), &.{.semicolon})) return error.UnexpectedToken;

    return nodeIndex;
}

fn parseExpression(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
    var nextToken = self.peek();
    if (nextToken.tag == .semicolon) @panic("Void return is not implemented");

    var expr = try self.parseTerm();
    nextToken = self.peek();

    while (nextToken.tag != .semicolon and nextToken.tag != .closeParen) : (nextToken = self.peek()) {
        const op = self.pop();
        if (!try self.expect(op, &.{ .plus, .minus, .asterik, .slash, .caret })) return error.UnexpectedToken;

        var tag: Node.Tag = undefined;
        switch (op.tag) {
            .minus => tag = .subtraction,
            .plus => tag = .addition,
            .asterik => tag = .multiplication,
            .slash => tag = .division,
            .caret => tag = .power,
            else => unreachable,
        }

        const right = try self.parseTerm();

        const node = &self.temp.items[expr];
        if (node.tag != .lit and node.tag != .parentesis and node.tag != .load and Expression.operandPresedence(node.tag) > Expression.operandPresedence(tag)) {
            const leftRight = node.data[1];
            node.*.data[1] = self.temp.items.len;
            _ = try nl.addNode(&self.temp, .{
                .tag = tag,
                .token = op,
                .data = .{ leftRight, right },
            });
        } else {
            expr = try nl.addNode(&self.temp, .{
                .tag = tag,
                .token = op,
                .data = .{ expr, right },
            });
        }
    }

    return expr;
}

fn parseTerm(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
    const nextToken = self.peek();

    if (!try self.expect(nextToken, &[_]Lexer.TokenType{ .numberLiteral, .openParen, .minus, .iden })) return error.UnexpectedToken;

    switch (nextToken.tag) {
        .numberLiteral => {
            return try nl.addNode(&self.temp, .{
                .tag = .lit,
                .token = self.pop(),
                .data = .{ 0, 0 },
            });
        },
        .iden => {
            return try nl.addNode(&self.temp, .{
                .tag = .load,
                .token = self.pop(),
                .data = .{ 0, 0 },
            });
        },
        .minus => {
            const op = self.pop();

            const expr = try self.parseTerm();

            return try nl.addNode(&self.temp, .{
                .tag = switch (op.tag) {
                    .minus => .neg,
                    else => unreachable,
                },
                .token = op,
                .data = .{ expr, 0 },
            });
        },
        .openParen => {
            self.depth += 1;

            _ = self.pop();

            const expr = try self.parseExpression();
            if (!try self.expect(self.peek(), &.{.closeParen})) return error.UnexpectedToken;

            _ = self.pop();

            std.debug.assert(self.depth != 0);
            self.depth -= 1;

            try self.temp.append(.{
                .tag = .parentesis,
                .token = null,
                .data = .{ expr, 0 },
            });

            return self.temp.items.len - 1;
        },
        else => unreachable,
    }
}

pub fn lexerToString(self: *@This(), alloc: std.mem.Allocator) std.mem.Allocator.Error!std.ArrayList(u8) {
    return self.l.toString(alloc);
}

pub fn toString(self: *@This(), alloc: std.mem.Allocator) std.mem.Allocator.Error!std.ArrayList(u8) {
    var cont = std.ArrayList(u8).init(alloc);
    if (self.nodeList.items.len == 0) return cont;

    const root = self.nodeList.items[0];

    var i = root.data[0];
    const end = root.data[1];
    while (i < end) : (i += 1) {
        const node = self.nodeList.items[i];
        switch (node.tag) {
            .funcDecl => {
                try cont.appendSlice("fn ");

                try cont.appendSlice(node.token.?.getText(self.source));

                try self.toStringFuncProto(&cont, 0, node.data[0]);

                const scope = self.nodeList.items[node.data[1]];
                switch (scope.tag) {
                    .scope => try self.toStringScope(&cont, 0, node.data[1]),
                    else => try self.toStringStatement(&cont, 0, node.data[1]),
                }
                i = scope.data[1];
            },
            else => unreachable,
        }
    }

    return cont;
}

fn toStringFuncProto(self: @This(), cont: *std.ArrayList(u8), d: u64, i: usize) std.mem.Allocator.Error!void {
    std.debug.assert(self.nodeList.items[i].tag == .funcProto);
    std.debug.assert(self.nodeList.items[i].data[0] == 0);

    // TODO : Put arguments
    try cont.appendSlice("() ");

    try self.toStringType(cont, d, self.nodeList.items[i].data[1]);

    try cont.append(' ');
}

fn toStringType(self: @This(), cont: *std.ArrayList(u8), d: u64, i: usize) std.mem.Allocator.Error!void {
    _ = d;
    try cont.appendSlice(self.nodeList.items[i].token.?.getText(self.source));
}

fn toStringScope(self: @This(), cont: *std.ArrayList(u8), d: u64, i: usize) std.mem.Allocator.Error!void {
    const scope = self.nodeList.items[i];
    std.debug.assert(scope.tag == .scope);

    try cont.appendSlice("{ \n");

    var j = scope.data[0];
    const end = scope.data[1];

    while (j < end) {
        const node = self.nodeList.items[j];

        try self.toStringStatement(cont, d + 4, j);

        j = node.data[1];
    }

    try cont.appendSlice("} \n");
}

fn toStringStatement(self: @This(), cont: *std.ArrayList(u8), d: u64, i: usize) std.mem.Allocator.Error!void {
    for (0..d) |_| {
        try cont.append(' ');
    }

    const stmt = self.nodeList.items[i];

    switch (stmt.tag) {
        .ret => {
            try cont.appendSlice("return ");
            try self.toStringExpression(cont, d, stmt.data[0]);
        },
        .variable, .constant => {
            try self.tostringVariable(cont, d, i);
        },
        else => unreachable,
    }

    try cont.appendSlice(";\n");
}

fn tostringVariable(self: @This(), cont: *std.ArrayList(u8), d: u64, i: usize) std.mem.Allocator.Error!void {
    const variable = self.nodeList.items[i];
    std.debug.assert(variable.tag == .constant or variable.tag == .variable);

    try cont.appendSlice(variable.token.?.getText(self.source));

    const proto = self.nodeList.items[variable.data[0]];
    std.debug.assert(proto.tag == .VarProto);

    if (proto.data[0] == 0)
        try cont.append(' ');

    try cont.append(':');
    if (proto.data[0] != 0) {
        try cont.append(' ');
        try self.toStringType(cont, d, proto.data[0]);
        try cont.append(' ');
    }

    if (proto.data[1] != 0) {
        switch (variable.tag) {
            .constant => try cont.appendSlice(": "),
            .variable => try cont.appendSlice("= "),
            else => unreachable,
        }
        try self.toStringExpression(cont, d, proto.data[1]);
    }
}

fn toStringExpression(self: @This(), cont: *std.ArrayList(u8), d: u64, i: usize) std.mem.Allocator.Error!void {
    const node = self.nodeList.items[i];
    switch (node.tag) {
        .addition, .subtraction, .multiplication, .division, .power => {
            try cont.append('(');

            const leftIndex = node.data[0];
            try self.toStringExpression(cont, d, leftIndex);

            try cont.append(' ');
            try cont.appendSlice(node.token.?.tag.toSymbol().?);
            try cont.append(' ');

            const rightIndex = node.data[1];
            try self.toStringExpression(cont, d, rightIndex);

            try cont.append(')');
        },
        .parentesis => {
            const leftIndex = node.data[0];

            try self.toStringExpression(cont, d, leftIndex);
        },
        .neg => {
            try cont.appendSlice(node.token.?.tag.toSymbol().?);
            try cont.append('(');
            const leftIndex = node.data[0];

            try self.toStringExpression(cont, d, leftIndex);
            try cont.append(')');
        },
        .load => {
            try cont.appendSlice(node.token.?.getText(self.source));
        },
        .lit => {
            try cont.appendSlice(node.token.?.getText(self.source));
        },
        else => unreachable,
    }
}
