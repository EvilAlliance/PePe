const std = @import("std");
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

const Result = util.Result;

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

pub fn init(alloc: Allocator, l: *Lexer) @This() {
    return @This(){
        .alloc = alloc,
        .l = l,
        .program = Program.init(alloc),
    };
}

pub fn deinit(self: *@This()) void {
    self.program.deinit();
}

pub fn parse(self: *@This()) error{OutOfMemory}!?UnexpectedToken {
    return try self.parseGlobalScope();
}

pub fn expect(token: Token, t: TokenType) ?UnexpectedToken {
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

pub fn parseGlobalScope(self: *@This()) error{OutOfMemory}!?UnexpectedToken {
    var t = self.l.peek();
    if (t.type == .EOF) return null;
    while (t.type != .EOF) : (t = self.l.peek()) {
        switch (t.type) {
            .func => {
                const r = try Function.parse(self);
                switch (r) {
                    .ok => try self.program.funcs.put(r.ok.name, r.ok),
                    .err => return r.err,
                }
                return null;
            },
            else => unreachable,
        }
    }

    return expect(t, .any);
}

pub fn toString(self: *@This(), alloc: std.mem.Allocator) error{OutOfMemory}!std.ArrayList(u8) {
    var cont = std.ArrayList(u8).init(alloc);
    try self.program.toString(&cont);
    return cont;
}
