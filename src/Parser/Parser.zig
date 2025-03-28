const std = @import("std");
const Logger = @import("../Logger.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const util = @import("../Util.zig");
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

l: *Lexer,
alloc: Allocator,

program: Program,
nodeList: NodeList,
temp: NodeList,

errors: std.ArrayList(UnexpectedToken),

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
    const is = util.listContains(Lexer.TokenType, ex, token.tag);
    if (!is)
        try self.errors.append(UnexpectedToken{
            .expected = ex,
            .found = token.tag,
            .loc = token.loc,
            .alloc = self.alloc,
        });

    return is;
}

pub fn parse(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!void {
    try self.parseRoot();
    if (self.errors.items.len > 0) return error.UnexpectedToken;
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

pub fn parseRoot(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!void {
    const top = self.temp.items.len;
    defer self.temp.shrinkRetainingCapacity(top);

    try self.temp.insert(0, .{ .tag = .root, .token = null, .data = .{ 1, 0 } });

    var t = self.peek();
    while (t.tag != .EOF) : (t = self.l.peek()) {
        switch (t.tag) {
            .func => try self.parseFuncDelc(),
            .let => unreachable,
            else => {
                if (!try self.expect(t, &.{ .func, .let })) return error.UnexpectedToken;
            },
        }
    }
}

pub fn parseFuncDelc(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!void {
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
    self.temp.items[nodeIndex].data[0] = try self.parseFuncProto();

    if (self.peek().tag == .openBrace) unreachable;
    // TODO: add Parsing for Basic1, instead of a scope, make a only one statement

    self.temp.items[nodeIndex].data[1] = try self.parseFuncBody();
}

pub fn parseFuncProto(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
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

    self.temp.items[nodeIndex].data[1] = try self.parseType();

    return nodeIndex;
}

pub fn parseType(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
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

pub fn parseFuncBody(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!usize {
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

    return self.temp.items.len;
}

pub fn parseStatement(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!void {
    switch (self.peek().tag) {
        .ret => unreachable,
        .let => unreachable,
        else => {
            _ = try self.expect(self.peek(), &.{ .ret, .let });
            return error.UnexpectedToken;
        },
    }
    unreachable;
}

pub fn toString(self: *@This(), alloc: std.mem.Allocator) std.mem.Allocator.Error!std.ArrayList(u8) {
    _ = self;
    _ = alloc;
    unreachable;
}
