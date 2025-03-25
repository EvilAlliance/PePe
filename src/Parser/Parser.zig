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
const TokenType = Lexer.TokenType;
const Token = Lexer.Token;
const Location = Lexer.Location;

pub const Expression = @import("./Expression.zig").Expression;
pub const Function = @import("./Function.zig");
pub const Return = @import("./Return.zig");
pub const Program = @import("./Program.zig");
pub const UnexpectedToken = @import("./UnexpectedToken.zig");
pub const Primitive = @import("./Primitive.zig");
pub const Statement = @import("./Statement.zig").Statement;
pub const Statements = std.ArrayList(Statement);
pub const Variable = @import("./Variable.zig");

l: *Lexer,
alloc: Allocator,
program: Program,
errors: std.ArrayList(UnexpectedToken),
temp: std.ArrayList(TokenType),

pub fn init(alloc: Allocator, l: *Lexer) @This() {
    return @This(){
        .alloc = alloc,
        .l = l,
        .program = Program.init(alloc),
        .errors = std.ArrayList(UnexpectedToken).init(alloc),
        .temp = std.ArrayList(TokenType).init(alloc),
    };
}

pub fn deinit(self: *@This()) void {
    for (self.errors.items) |value| {
        value.deinit();
    }

    self.errors.deinit();
    self.program.deinit();
}

pub fn parse(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!void {
    try self.parseGlobalScope();
    if (self.errors.items.len > 0) return error.UnexpectedToken;
}

pub fn expect(self: *@This(), token: Token, t: []const TokenType) std.mem.Allocator.Error!bool {
    const ex = try self.alloc.dupe(Lexer.TokenType, t);
    const is = util.listContains(TokenType, ex, token.type);
    if (!is)
        try self.errors.append(UnexpectedToken{
            .expected = ex,
            .found = token.type,
            .loc = token.loc,
            .path = token.path,
            .alloc = self.alloc,
        });

    return is;
}

pub fn parseGlobalScope(self: *@This()) (std.mem.Allocator.Error || error{UnexpectedToken})!void {
    var t = self.l.peek();
    if (t.type == .EOF) return;
    while (t.type != .EOF) : (t = self.l.peek()) {
        switch (t.type) {
            .func => {
                const r = try Function.parse(self);
                try self.program.funcs.put(r.name, r);
            },
            else => {
                _ = if (!try self.expect(t, &[_]Lexer.TokenType{.func})) return error.UnexpectedToken;
            },
        }
    }
}

pub fn toString(self: *@This(), alloc: std.mem.Allocator) std.mem.Allocator.Error!std.ArrayList(u8) {
    var cont = std.ArrayList(u8).init(alloc);
    try self.program.toString(&cont);
    return cont;
}
