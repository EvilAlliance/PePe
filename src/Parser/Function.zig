const std = @import("std");
const Logger = @import("../Logger.zig");
const assert = std.debug.assert;

const Parser = @import("./Parser.zig");
const Primitive = Parser.Primitive;
const UnexpectedToken = Parser.UnexpectedToken;
const Statement = Parser.Statement;
const Statements = Parser.Statements;

const Lexer = @import("../Lexer/Lexer.zig");
const Location = @import("../Lexer/Location.zig");

const IR = @import("../IR/IR.zig");

const tb = @import("../libs/tb/tb.zig");
const tbHelper = @import("../TBHelper.zig");

const Util = @import("../Util.zig");
const Result = Util.Result;

name: []const u8,
//args: void,
body: Statements,
returnType: Primitive,
loc: Location,

pub fn parse(p: *Parser) (std.mem.Allocator.Error || error{UnexpectedToken})!@This() {
    const func = p.l.peek();
    assert(func.type == .func);

    _ = p.l.pop();

    const name = p.l.pop();
    if (!try p.expect(name, &[_]Lexer.TokenType{.iden})) return error.UnexpectedToken;
    const funcLoc = name.loc;

    var separator = p.l.pop();

    if (!try p.expect(separator, &[_]Lexer.TokenType{.openParen})) return error.UnexpectedToken;

    // TODO: ARGS

    separator = p.l.pop();

    if (!try p.expect(separator, &[_]Lexer.TokenType{.closeParen})) return error.UnexpectedToken;

    const ret = p.l.pop();

    if (!try p.expect(ret, &[_]Lexer.TokenType{.iden})) return error.UnexpectedToken;

    separator = p.l.pop();

    if (!try p.expect(separator, &[_]Lexer.TokenType{.openBrace})) return error.UnexpectedToken;

    const state = try parseBody(p);

    separator = p.l.pop();

    if (!try p.expect(separator, &[_]Lexer.TokenType{.closeBrace})) return error.UnexpectedToken;

    return @This(){
        .name = name.str,
        // .args = void,
        .returnType = Primitive.getType(ret.str),
        .body = state,
        .loc = funcLoc,
    };
}

fn parseBody(p: *Parser) std.mem.Allocator.Error!Statements {
    var statements = Statements.init(p.alloc);

    var t = p.l.peek();

    while (t.type != .closeBrace) : (t = p.l.peek()) {
        const state = Statement.parse(p, t) catch |err| switch (err) {
            error.UnexpectedToken => {
                while (p.l.peek().type != .semicolon) : (_ = p.l.pop()) {}
                _ = p.l.pop();
                continue;
            },
            else => |e| return e,
        };

        try statements.append(state);
    }

    return statements;
}

pub fn toIR(self: @This(), alloc: std.mem.Allocator, prog: *IR.Program, m: tb.Module) std.mem.Allocator.Error!IR.Function {
    var f = IR.Function.init(alloc, self, m);
    for (self.body.items) |stmt| {
        const inst = try stmt.toIR(alloc, prog, m);
        if (inst) |i|
            try f.body.append(i);
    }

    return f;
}

pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) std.mem.Allocator.Error!void {
    for (0..d) |_|
        try cont.append(' ');

    try cont.appendSlice("Function:\n");

    for (0..d + 2) |_|
        try cont.append(' ');

    try cont.appendSlice("Name: ");
    try cont.appendSlice(self.name);
    try cont.append('\n');

    for (0..d + 2) |_|
        try cont.append(' ');

    try cont.appendSlice("Return Type: ");
    try self.returnType.toString(cont);
    try cont.append('\n');

    for (0..d + 2) |_|
        try cont.append(' ');

    try cont.appendSlice("Body:\n");

    for (self.body.items) |statement| {
        try statement.toString(cont, d + 4);
    }
}
