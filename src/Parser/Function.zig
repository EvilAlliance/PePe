const std = @import("std");
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

pub fn parse(p: *Parser) error{OutOfMemory}!Result(@This(), UnexpectedToken) {
    const r = Result(@This(), UnexpectedToken);

    var unexpected: ?UnexpectedToken = undefined;

    const func = p.l.peek();
    assert(func.type == .func);

    _ = p.l.pop();

    const name = p.l.pop();
    unexpected = Parser.expect(name, .iden);
    if (unexpected) |u| return r.Err(u);
    const funcLoc = name.loc;

    var separator = p.l.pop();
    unexpected = Parser.expect(separator, .openParen);
    if (unexpected) |u| return r.Err(u);

    // TODO: ARGS

    separator = p.l.pop();
    unexpected = Parser.expect(separator, .closeParen);
    if (unexpected) |u| return r.Err(u);

    const ret = p.l.pop();
    unexpected = Parser.expect(ret, .iden);
    if (unexpected) |u| return r.Err(u);

    separator = p.l.pop();
    unexpected = Parser.expect(separator, .openBrace);
    if (unexpected) |u| return r.Err(u);

    const state = try parseBody(p);
    switch (state) {
        .ok => {},
        .err => return r.Err(state.err),
    }

    separator = p.l.pop();
    unexpected = Parser.expect(separator, .closeBrace);
    if (unexpected) |u| return r.Err(u);

    return r.Ok(@This(){
        .name = name.str,
        // .args = void,
        .returnType = Primitive.getType(ret.str),
        .body = state.ok,
        .loc = funcLoc,
    });
}

fn parseBody(p: *Parser) error{OutOfMemory}!Result(Statements, UnexpectedToken) {
    const r = Result(Statements, UnexpectedToken);
    var statements = Statements.init(p.alloc);

    var t = p.l.peek();

    while (t.type != .closeBrace) : (t = p.l.peek()) {
        const state = try Statement.parse(p, t);

        switch (state) {
            .ok => try statements.append(state.ok),
            .err => return r.Err(state.err),
        }
    }

    return r.Ok(statements);
}

pub fn toIR(self: @This(), alloc: std.mem.Allocator, prog: *IR.Program, m: tb.Module) error{OutOfMemory}!IR.Function {
    var f = IR.Function.init(alloc, self, m);
    for (self.body.items) |stmt| {
        const inst = try stmt.toIR(alloc, prog, m);
        if (inst) |i|
            try f.body.append(i);
    }

    return f;
}

pub fn toString(self: @This(), cont: *std.ArrayList(u8), d: u64) error{OutOfMemory}!void {
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
