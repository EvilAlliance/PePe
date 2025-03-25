const std = @import("std");

pub const Parser = @import("./Parser.zig");
pub const Function = Parser.Function;
pub const Return = Parser.Return;
pub const UnexpectedToken = Parser.UnexpectedToken;
pub const Variable = Parser.Variable;

pub const Lexer = @import("../Lexer/Lexer.zig");
pub const Token = Lexer.Token;

pub const IR = @import("../IR/IR.zig");

pub const tb = @import("../libs/tb/tb.zig");

const Util = @import("../Util.zig");
const Result = Util.Result;

pub const Statement = union(enum) {
    ret: Return,
    func: Function,
    let: Variable,

    pub fn parse(p: *Parser, t: Token) (std.mem.Allocator.Error || error{UnexpectedToken})!@This() {
        switch (t.type) {
            .ret => {
                const state = try Return.parse(p);
                return @This(){ .ret = state };
            },
            .let => {
                const state = try Variable.parse(p);
                return @This(){ .let = state };
            },
            .EOF => {
                _ = try p.expect(t, &[_]Lexer.TokenType{.closeBrace});
                return error.UnexpectedToken;
            },
            else => {
                const temp = p.temp.addManyAsArray(3) catch unreachable;
                temp[0] = .ret;
                temp[1] = .let;
                _ = try p.expect(t, &[_]Lexer.TokenType{ .ret, .let });
                return error.UnexpectedToken;
            },
        }
    }

    pub fn toIR(self: @This(), alloc: std.mem.Allocator, prog: *IR.Program, m: tb.Module) std.mem.Allocator.Error!?IR.Instruction {
        switch (self) {
            .ret => |r| return IR.Instruction{ .ret = r.toIR() },
            .let => |v| return IR.Instruction{ .variable = v.toIR() },
            .func => |f| try prog.funcs.put(f.name, try f.toIR(alloc, prog, m)),
        }
        return null;
    }

    pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) std.mem.Allocator.Error!void {
        switch (self) {
            .ret => |ret| try ret.toString(cont, d),
            .let => |let| try let.toString(cont, d),
            .func => |func| try func.toString(cont, d),
        }
    }
};
