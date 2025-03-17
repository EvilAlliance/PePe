const std = @import("std");

pub const Function = @import("./Function.zig");
pub const Return = @import("./Return.zig");
pub const Parser = @import("./Parser.zig");
pub const UnexpectedToken = @import("./UnexpectedToken.zig");

pub const Lexer = @import("../Lexer/Lexer.zig");
pub const Token = Lexer.Token;

const Util = @import("../Util.zig");
const Result = Util.Result;

pub const Statement = union(enum) {
    ret: Return,
    func: Function,

    pub fn parse(p: *Parser, t: Token) Result(@This(), UnexpectedToken) {
        const r = Result(@This(), UnexpectedToken);
        switch (t.type) {
            .ret => {
                const state = Return.parse(p);
                switch (state) {
                    .ok => return r.Ok(@This(){ .ret = state.ok }),
                    .err => return r.Err(state.err),
                }
            },
            .EOF => {
                const unexpected = Parser.expect(t, .closeBrace);
                return r.Err(unexpected.?);
            },
            else => {
                const unexpected = Parser.expect(t, .any);
                return r.Err(unexpected.?);
            },
        }
    }

    pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
        switch (self) {
            .ret => |ret| try ret.toString(cont, d),
            .func => |func| try func.toString(cont, d),
        }
    }
};
