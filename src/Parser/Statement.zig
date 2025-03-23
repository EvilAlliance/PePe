const std = @import("std");

pub const Parser = @import("./Parser.zig");
pub const Function = Parser.Function;
pub const Return = Parser.Return;
pub const UnexpectedToken = Parser.UnexpectedToken;

pub const Lexer = @import("../Lexer/Lexer.zig");
pub const Token = Lexer.Token;

pub const IR = @import("../IR/IR.zig");

pub const tb = @import("../libs/tb/tb.zig");

const Util = @import("../Util.zig");
const Result = Util.Result;

pub const Statement = union(enum) {
    ret: Return,
    func: Function,

    pub fn parse(p: *Parser, t: Token) error{OutOfMemory}!Result(@This(), UnexpectedToken) {
        const r = Result(@This(), UnexpectedToken);
        switch (t.type) {
            .ret => {
                const state = try Return.parse(p);
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

    pub fn toIR(self: @This(), alloc: std.mem.Allocator, prog: *IR.Program, m: tb.Module) error{OutOfMemory}!?IR.Instruction {
        switch (self) {
            .ret => |r| return IR.Instruction{
                .ret = r.toIR(),
            },
            .func => |f| try prog.funcs.put(f.name, try f.toIR(alloc, prog, m)),
        }
        return null;
    }

    pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
        switch (self) {
            .ret => |ret| try ret.toString(cont, d),
            .func => |func| try func.toString(cont, d),
        }
    }
};
