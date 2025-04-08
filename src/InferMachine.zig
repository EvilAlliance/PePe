const std = @import("std");
const Logger = @import("./Logger.zig");
const Util = @import("./Util.zig");
const Lexer = @import("Lexer/Lexer.zig");
const Parser = @import("Parser/Parser.zig");

const VarTOset = std.HashMap(
    Parser.Node,
    usize,
    struct {
        pub fn hash(self: @This(), a: Parser.Node) u64 {
            _ = self;
            const col = std.hash.int(a.token.?.loc.col);
            const row = std.hash.int(a.token.?.loc.row);

            return col ^ row;
        }
        pub fn eql(self: @This(), a: Parser.Node, b: Parser.Node) bool {
            _ = self;
            return a.token.?.loc.col == b.token.?.loc.col and a.token.?.loc.row == b.token.?.loc.row;
        }
    },
    70,
);

const SetTOvar = std.AutoHashMap(
    usize,
    struct {
        ?struct { Parser.Node, Lexer.Location },
        std.ArrayList(*Parser.Node),
    },
);

reuse: std.BoundedArray(usize, 256),
sets: usize = 0,
alloc: std.mem.Allocator,
varTOset: VarTOset,
setTOvar: SetTOvar,

pub fn init(alloc: std.mem.Allocator) @This() {
    return @This(){
        .reuse = std.BoundedArray(usize, 256).init(0) catch unreachable,
        .alloc = alloc,
        .varTOset = VarTOset.init(alloc),
        .setTOvar = SetTOvar.init(alloc),
    };
}

pub fn deinit(self: *@This()) void {
    self.varTOset.deinit();
    self.setTOvar.deinit();
}

pub fn add(self: *@This(), node: *Parser.Node) std.mem.Allocator.Error!usize {
    if (self.varTOset.get(node.*)) |index| return index;
    const sets = self.reuse.pop() orelse set: {
        const index = self.sets;
        self.sets += 1;
        break :set index;
    };
    try self.varTOset.put(node.*, sets);

    if (self.setTOvar.getPtr(sets)) |set| {
        try set[1].append(node);
    } else {
        var set = std.ArrayList(*Parser.Node).init(self.alloc);
        try set.append(node);
        try self.setTOvar.put(sets, .{ null, set });
    }

    return sets;
}

pub fn merge(self: *@This(), a: usize, b: usize) (std.mem.Allocator.Error || error{IncompatibleType})!usize {
    const ta = self.setTOvar.getPtr(a).?;
    const tb = self.setTOvar.getPtr(b).?;

    if (ta[0]) |aType| {
        if (tb[0]) |bType| {
            if (aType[0].token.?.tag != bType[0].token.?.tag) return error.IncompatibleType;
        }
    }

    var dest: *struct { ?struct { Parser.Node, Lexer.Location }, std.ArrayList(*Parser.Node) } = undefined;
    var org: *struct { ?struct { Parser.Node, Lexer.Location }, std.ArrayList(*Parser.Node) } = undefined;
    var orgIndex: usize = undefined;

    if (ta[0] != null) {
        dest = ta;
        org = tb;

        orgIndex = a;
        self.reuse.append(b) catch unreachable;
    } else {
        dest = tb;
        org = ta;

        orgIndex = b;
        self.reuse.append(a) catch unreachable;
    }
    try dest[1].appendSlice(org[1].items);

    for (org[1].items) |value| {
        try self.varTOset.put(value.*, orgIndex);
    }

    org[1].clearRetainingCapacity();
    org[0] = null;

    return orgIndex;
}

pub fn found(self: *@This(), a: Parser.Node, t: Parser.Node, loc: Lexer.Location) void {
    std.debug.assert(t.tag == .type);
    const ta = self.setTOvar.getPtr(self.varTOset.get(a).?).?;
    if (ta[0]) |oldT| {
        if (oldT[0].token.?.tag != t.token.?.tag) {
            Logger.logLocation.err(a.token.?.loc, "Found this variable used in 2 different contexts (ambiguous typing)", .{});
            Logger.logLocation.info(oldT[1], "Type inferred is: {s}, found here", .{oldT[0].token.?.tag.getName()});
            Logger.logLocation.info(loc, "But later found here used in an other context: {s}", .{t.token.?.tag.getName()});
        }
    } else {
        ta[0] = .{ t, loc };
    }
}

pub fn printState(self: @This()) void {
    var it = self.setTOvar.keyIterator();

    while (it.next()) |setIndex| {
        if (Util.listContains(usize, &self.reuse.buffer, setIndex.*)) continue;
        Logger.log.info("{}:", .{setIndex.*});
        const set = self.setTOvar.get(setIndex.*).?;

        if (set[0]) |t| {
            Logger.log.info("{s}", .{t[0].token.?.tag.getName()});
            Logger.logLocation.info(t[1], "Found here", .{});
        }

        for (set[1].items) |value| {
            Logger.logLocation.info(value.token.?.loc, "", .{});
        }
    }
}
