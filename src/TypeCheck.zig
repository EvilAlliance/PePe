const std = @import("std");
const Util = @import("Util.zig");
const Logger = @import("Logger.zig");

const Parser = @import("./Parser/Parser.zig");

const Scope = std.StringHashMap(Parser.Node);
const Scopes = std.ArrayList(*Scope);

const TypeChecker = struct {
    const Self = @This();

    errs: usize = 0,

    alloc: std.mem.Allocator,

    ast: Parser.Ast,
    scopes: Scopes,
    pub fn init(alloc: std.mem.Allocator, ast: Parser.Ast) std.mem.Allocator.Error!bool {
        var checker = @This(){
            .alloc = alloc,
            .ast = ast,
            .scopes = Scopes.init(alloc),
        };

        var it = checker.ast.functions.valueIterator();

        Logger.log.err("Her", .{});
        while (it.next()) |func| {
            try checker.checkFunction(checker.ast.nodeList.items[func.*]);
        }

        return checker.errs > 0;
    }

    pub fn deinit(self: Self) void {
        for (self.scopes.items) |s|
            s.deinit();

        self.scopes.deinit();
    }

    fn checkFunction(self: *Self, node: Parser.Node) std.mem.Allocator.Error!void {
        std.debug.assert(node.tag == .funcDecl);

        const proto = self.ast.nodeList.items[node.data[0]];
        const t = self.ast.nodeList.items[proto.data[1]];

        const stmtORscope = self.ast.nodeList.items[node.data[1]];

        if (stmtORscope.tag == .scope) {
            try self.checkScope(stmtORscope, t);
        } else {
            var scope = Scope.init(self.alloc);
            try self.scopes.append(&scope);
            try self.checkStatements(stmtORscope, t);
            _ = self.scopes.pop();
        }
    }

    fn checkScope(self: *Self, scope: Parser.Node, retType: Parser.Node) std.mem.Allocator.Error!void {
        std.debug.assert(scope.tag == .scope and retType.tag == .type);

        var scopeMap = Scope.init(self.alloc);
        try self.scopes.append(&scopeMap);

        var i = scope.data[0];
        const end = scope.data[1];

        while (i < end) {
            const stmt = self.ast.nodeList.items[i];

            try self.checkStatements(stmt, retType);

            i = stmt.data[1];
        }

        _ = self.scopes.pop();
    }

    fn checkStatements(self: *Self, stmt: Parser.Node, retType: Parser.Node) std.mem.Allocator.Error!void {
        switch (stmt.tag) {
            .ret => {
                const expr = self.ast.nodeList.items[stmt.data[0]];

                self.checkExpressionExpectedType(expr, retType);
            },
            .variable, .constant => {
                try self.scopes.getLast().put(stmt.token.?.getText(self.ast.source), stmt);
                const proto = self.ast.nodeList.items[stmt.data[0]];
                if (proto.data[0] != 0) {
                    const t = self.ast.nodeList.items[proto.data[0]];
                    if (proto.data[1] != 0) {
                        const expr = self.ast.nodeList.items[proto.data[1]];
                        self.checkExpressionExpectedType(expr, t);
                    }
                } else {
                    Logger.logLocation.err(stmt.token.?.loc, "Type Inference not implemented", .{});
                    unreachable;
                }
            },
            else => unreachable,
        }
    }

    fn checkExpressionExpectedType(self: *Self, expr: Parser.Node, expectedType: Parser.Node) void {
        std.debug.assert(expectedType.tag == .type);
        std.debug.assert(Util.listContains(Parser.Node.Tag, &.{ .lit, .load, .neg, .parentesis, .power, .division, .multiplication, .subtraction, .addition }, expr.tag));

        switch (expr.tag) {
            .lit => {
                const text = expr.token.?.getText(self.ast.source);

                switch (expectedType.token.?.tag) {
                    .unsigned8 => {
                        _ = std.fmt.parseUnsigned(u8, text, 10) catch {
                            Logger.logLocation.err(expr.token.?.loc, "Number literal is too large for the expected type {s}", .{expectedType.token.?.tag.getName()});
                            self.errs += 1;
                        };
                    },
                    .unsigned16 => {
                        _ = std.fmt.parseUnsigned(u16, text, 10) catch {
                            Logger.logLocation.err(expr.token.?.loc, "Number literal is too large for the expected type {s}", .{expectedType.token.?.tag.getName()});
                            self.errs += 1;
                        };
                    },
                    .unsigned32 => {
                        _ = std.fmt.parseUnsigned(u32, text, 10) catch {
                            Logger.logLocation.err(expr.token.?.loc, "Number literal is too large for the expected type {s}", .{expectedType.token.?.tag.getName()});
                            self.errs += 1;
                        };
                    },
                    .unsigned64 => {
                        _ = std.fmt.parseUnsigned(u64, text, 10) catch {
                            Logger.logLocation.err(expr.token.?.loc, "Number literal is too large for the expected type {s}", .{expectedType.token.?.tag.getName()});
                            self.errs += 1;
                        };
                    },

                    .signed8 => {
                        _ = std.fmt.parseInt(i8, text, 10) catch {
                            Logger.logLocation.err(expr.token.?.loc, "Number literal is too large for the expected type {s}", .{expectedType.token.?.tag.getName()});
                            self.errs += 1;
                        };
                    },
                    .signed16 => {
                        _ = std.fmt.parseInt(i16, text, 10) catch {
                            Logger.logLocation.err(expr.token.?.loc, "Number literal is too large for the expected type {s}", .{expectedType.token.?.tag.getName()});
                            self.errs += 1;
                        };
                    },
                    .signed32 => {
                        _ = std.fmt.parseInt(i32, text, 10) catch {
                            Logger.logLocation.err(expr.token.?.loc, "Number literal is too large for the expected type {s}", .{expectedType.token.?.tag.getName()});
                            self.errs += 1;
                        };
                    },
                    .signed64 => {
                        _ = std.fmt.parseInt(i64, text, 10) catch {
                            Logger.logLocation.err(expr.token.?.loc, "Number literal is too large for the expected type {s}", .{expectedType.token.?.tag.getName()});
                            self.errs += 1;
                        };
                    },
                    else => unreachable,
                }
            },
            .load => {
                const v = self.scopes.getLast().get(expr.token.?.getText(self.ast.source));

                if (v == null) {
                    Logger.logLocation.err(expr.token.?.loc, "Unknown identifier in expression \"{s}\"", .{expr.token.?.getText(self.ast.source)});
                    self.errs += 1;
                }
            },
            .parentesis, .neg => {
                const left = self.ast.nodeList.items[expr.data[0]];

                self.checkExpressionExpectedType(left, expectedType);
            },
            .addition, .subtraction, .multiplication, .division, .power => {
                const left = self.ast.nodeList.items[expr.data[0]];
                const right = self.ast.nodeList.items[expr.data[1]];

                self.checkExpressionExpectedType(left, expectedType);
                self.checkExpressionExpectedType(right, expectedType);
            },
            else => {
                Logger.logLocation.err(expr.token.?.loc, "Node not supported {}", .{expr.tag});
                unreachable;
            },
        }
    }
};

pub fn typeCheck(p: Parser.Ast) std.mem.Allocator.Error!bool {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();
    return try TypeChecker.init(alloc, p);
}
