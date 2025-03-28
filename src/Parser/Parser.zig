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
pub const Program = std.StringHashMap(usize);
pub const NodeList = std.ArrayList(Node);
pub const Expression = @import("Expression.zig");

l: *Lexer,
alloc: Allocator,

program: Program,
nodeList: NodeList,
temp: NodeList,

errors: std.ArrayList(UnexpectedToken),

depth: usize = 0,

pub fn init(alloc: Allocator, l: *Lexer) @This() {
    return @This(){
        .alloc = alloc,
        .l = l,

        .program = Program.init(alloc),
        .nodeList = NodeList.init(alloc),
        .temp = NodeList.init(alloc),

        .errors = std.ArrayList(UnexpectedToken).init(alloc),
    };
}

pub fn deinit(self: *@This()) void {
    for (self.errors.items) |value| {
        value.deinit();
    }

    self.errors.deinit();

    self.program.deinit();
    self.nodeList.deinit();
    self.temp.deinit();
}

pub fn expect(self: *@This(), token: Lexer.Token, t: []const Lexer.TokenType) std.mem.Allocator.Error!bool {
    const ex = try self.alloc.dupe(Lexer.TokenType, t);
    const is = Util.listContains(Lexer.TokenType, ex, token.tag);
    if (!is)
        try self.errors.append(UnexpectedToken{
            .expected = ex,
            .found = token.tag,
            .loc = token.loc,
            .alloc = self.alloc,
        });

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

pub fn parse(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!void {
    try self.parseRoot();
    if (self.errors.items.len > 0) return error.UnexpectedToken;
}

fn parseRoot(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!void {
    const top = self.temp.items.len;
    defer self.temp.shrinkRetainingCapacity(top);

    try self.temp.insert(0, .{ .tag = .root, .token = null, .data = .{ 1, 0 } });

    var t = self.peek();
    if (!try self.expect(t, &[_]Lexer.TokenType{.func})) return error.UnexpectedToken;
    while (t.tag != .EOF) : (t = self.l.peek()) {
        if (!try self.expect(t, &.{ .func, .let })) return error.UnexpectedToken;

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

    const nodeIndex = self.temp.items.len;
    try self.temp.append(.{
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
        const p = try self.parseBody();
        self.temp.items[nodeIndex].data[1] = p;
    }
}

fn parseFuncProto(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
    const nodeIndex = self.temp.items.len;
    try self.temp.append(.{
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
    if (!try self.expect(self.peek(), &.{.iden})) return error.UnexpectedToken;
    const mainToken = self.pop();

    const nodeIndex = self.temp.items.len;
    try self.temp.append(.{
        .token = mainToken,
        .tag = .type,
        .data = .{ 0, 0 },
    });

    return nodeIndex;
}

fn parseBody(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
    _ = self.popIf(.openBrace) orelse unreachable;

    const nodeIndex = self.temp.items.len;

    try self.temp.append(.{
        .token = null,
        .tag = .body,
        .data = .{ nodeIndex + 1, 0 },
    });

    while (self.peek().tag != .closeBrace) {
        const top = self.temp.items.len;
        self.parseStatement() catch |err| switch (err) {
            error.UnexpectedToken => self.temp.shrinkRetainingCapacity(top),
            error.OutOfMemory => return error.OutOfMemory,
        };
    }

    if (!try self.expect(self.peek(), &.{.closeBrace})) return error.UnexpectedToken;
    _ = self.pop();

    self.temp.items[nodeIndex].data[1] = self.temp.items.len;

    return nodeIndex;
}

fn parseStatement(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!void {
    const nodeIndex = self.temp.items.len;
    if (!try self.expect(self.peek(), &.{.ret})) return error.UnexpectedToken;

    switch (self.peek().tag) {
        .ret => try self.parseReturn(),
        // .let => unreachable,
        else => unreachable,
    }

    if (!try self.expect(self.peek(), &.{.semicolon})) return error.UnexpectedToken;
    _ = self.pop();

    self.temp.items[nodeIndex].data[1] = self.temp.items.len;
    return;
}

fn parseReturn(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!void {
    const ret = self.popIf(.ret) orelse unreachable;

    const nodeIndex = self.temp.items.len;
    try self.temp.append(.{
        .tag = .ret,
        .token = ret,
        .data = .{ 0, 0 },
    });

    std.debug.assert(self.depth == 0);
    const exp = try self.parseExpression();
    std.debug.assert(self.depth == 0);

    self.temp.items[nodeIndex].data[0] = exp;

    if (!try self.expect(self.peek(), &.{.semicolon})) return error.UnexpectedToken;

    return;
}

fn parseExpression(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
    var nextToken = self.peek();
    if (nextToken.tag == .semicolon) @panic("Void return is not implemented");

    var expr = try self.parseTerm();
    nextToken = self.peek();

    while (nextToken.tag != .semicolon and nextToken.tag != .closeParen) : (nextToken = self.peek()) {
        const op = self.pop();
        if (!try self.expect(op, &.{.plus})) return error.UnexpectedToken;

        const right = try self.parseTerm();

        try self.temp.append(.{
            .tag = .plus,
            .token = op,
            .data = .{ expr, right },
        });

        expr = self.temp.items.len - 1;
    }

    return expr;
}

fn parseTerm(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
    const nextToken = self.peek();

    if (!try self.expect(nextToken, &[_]Lexer.TokenType{.numberLiteral})) return error.UnexpectedToken;

    if (nextToken.tag == .numberLiteral) {
        const nodeIndex = self.temp.items.len;

        try self.temp.append(.{
            .tag = .lit,
            .token = self.pop(),
            .data = .{ 0, 0 },
        });

        return nodeIndex;
    }

    unreachable;
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

                try cont.appendSlice(node.token.?.getText(self.l.content));

                try self.toStringFuncProto(&cont, 0, node.data[0]);

                const body = self.nodeList.items[node.data[1]];
                switch (body.tag) {
                    .body => try self.toStringBody(&cont, 0, node.data[1]),
                    else => try self.toStringStatement(&cont, 0, node.data[1]),
                }
                i = body.data[1];
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
}

fn toStringType(self: @This(), cont: *std.ArrayList(u8), d: u64, i: usize) std.mem.Allocator.Error!void {
    _ = d;
    try cont.appendSlice(self.nodeList.items[i].token.?.getText(self.l.content));
    try cont.append(' ');
}

fn toStringBody(self: @This(), cont: *std.ArrayList(u8), d: u64, i: usize) std.mem.Allocator.Error!void {
    const body = self.nodeList.items[i];
    std.debug.assert(body.tag == .body);

    try cont.appendSlice("{ \n");

    var j = body.data[0];
    const end = body.data[1];

    while (j < end) : (j += 1) {
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
        else => unreachable,
    }

    try cont.appendSlice(";\n");
}

fn toStringExpression(self: @This(), cont: *std.ArrayList(u8), d: u64, i: usize) std.mem.Allocator.Error!void {
    const node = self.nodeList.items[i];
    switch (node.tag) {
        .plus => {
            const leftIndex = node.data[0];
            try self.toStringExpression(cont, d, leftIndex);

            try cont.append(' ');
            try cont.appendSlice(node.token.?.tag.toSymbol().?);

            const rightIndex = node.data[1];
            try self.toStringExpression(cont, d, rightIndex);
        },
        .lit => {
            try cont.append(' ');
            try cont.appendSlice(node.token.?.getText(self.l.content));
        },
        else => unreachable,
    }
}
