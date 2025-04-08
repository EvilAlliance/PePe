const std = @import("std");
const Util = @import("Util.zig");
const Logger = @import("Logger.zig");
const InferMachine = @import("InferMachine.zig");

const Parser = @import("./Parser/Parser.zig");

const Scope = std.StringHashMap(*Parser.Node);
const Scopes = std.ArrayList(Scope);

const TypeChecker = struct {
    const Self = @This();

    errs: usize = 0,

    alloc: std.mem.Allocator,

    inferMachine: InferMachine,

    ast: Parser.Ast,
    scopes: Scopes,
    pub fn init(alloc: std.mem.Allocator, ast: Parser.Ast) std.mem.Allocator.Error!bool {
        var checker = @This(){
            .alloc = alloc,
            .inferMachine = InferMachine.init(alloc),
            .ast = ast,
            .scopes = Scopes.init(alloc),
        };
        defer checker.deinit();

        var it = checker.ast.functions.valueIterator();

        while (it.next()) |func| {
            try checker.checkFunction(&checker.ast.nodeList.items[func.*]);
        }

        checker.inferMachine.printState();

        return checker.errs > 0;
    }

    pub fn deinit(self: *Self) void {
        for (self.scopes.items) |*s|
            s.deinit();

        self.scopes.deinit();
        self.inferMachine.deinit();
    }

    fn checkFunction(self: *Self, node: *Parser.Node) std.mem.Allocator.Error!void {
        std.debug.assert(node.tag == .funcDecl);

        const proto = &self.ast.nodeList.items[node.data[0]];
        const t = self.ast.nodeList.items[proto.data[1]];

        const stmtORscope = &self.ast.nodeList.items[node.data[1]];

        if (stmtORscope.tag == .scope) {
            try self.checkScope(stmtORscope, t);
        } else {
            try self.scopes.append(Scope.init(self.alloc));
            try self.checkStatements(stmtORscope, t);
            _ = self.scopes.pop();
        }
    }

    fn checkScope(self: *Self, scope: *Parser.Node, retType: Parser.Node) std.mem.Allocator.Error!void {
        std.debug.assert(scope.tag == .scope and retType.tag == .type);

        try self.scopes.append(Scope.init(self.alloc));

        var i = scope.data[0];
        const end = scope.data[1];

        while (i < end) {
            const stmt = &self.ast.nodeList.items[i];

            try self.checkStatements(stmt, retType);

            i = stmt.data[1];
        }

        _ = self.scopes.pop();
    }

    fn checkStatements(self: *Self, stmt: *Parser.Node, retType: Parser.Node) std.mem.Allocator.Error!void {
        switch (stmt.tag) {
            .ret => {
                const expr = &self.ast.nodeList.items[stmt.data[0]];

                self.checkExpressionExpectedType(expr, retType);
            },
            .variable, .constant => {
                var dic = &self.scopes.items[self.scopes.items.len - 1];
                try dic.put(stmt.token.?.getText(self.ast.source), stmt);

                const a = try self.inferMachine.add(stmt);

                const proto = self.ast.nodeList.items[stmt.data[0]];

                if (proto.data[0] != 0) {
                    const t = self.ast.nodeList.items[proto.data[0]];

                    self.inferMachine.found(stmt.*, t, stmt.token.?.loc);

                    const expr = &self.ast.nodeList.items[proto.data[1]];
                    self.checkExpressionExpectedType(expr, t);
                } else {
                    const expr = &self.ast.nodeList.items[proto.data[1]];
                    const b = try self.checkExpressionInferType(expr);
                    if (b) |bS|
                        _ = self.inferMachine.merge(a, bS) catch |err| switch (err) {
                            error.IncompatibleType => unreachable,
                            error.OutOfMemory => return error.OutOfMemory,
                        };
                }
            },
            else => unreachable,
        }
    }
    fn checkExpressionInferType(self: *Self, expr: *Parser.Node) std.mem.Allocator.Error!?usize {
        std.debug.assert(Util.listContains(Parser.Node.Tag, &.{ .lit, .load, .neg, .parentesis, .power, .division, .multiplication, .subtraction, .addition }, expr.tag));
        switch (expr.tag) {
            .lit => {
                return null;
            },
            .load => {
                const variable = self.scopes.getLast().get(expr.token.?.getText(self.ast.source));

                if (variable) |v| {
                    return try self.inferMachine.add(v);
                } else {
                    Logger.logLocation.err(expr.token.?.loc, "Unknown identifier in expression \"{s}\"", .{expr.token.?.getText(self.ast.source)});
                    self.errs += 1;

                    return null;
                }
            },
            .parentesis, .neg => {
                const left = &self.ast.nodeList.items[expr.data[0]];

                return try self.checkExpressionInferType(left);
            },
            .addition, .subtraction, .multiplication, .division, .power => {
                const left = &self.ast.nodeList.items[expr.data[0]];
                const right = &self.ast.nodeList.items[expr.data[1]];

                const a = try self.checkExpressionInferType(left);
                const b = try self.checkExpressionInferType(right);

                if (a) |aS| {
                    if (b) |bS|
                        return self.inferMachine.merge(aS, bS) catch |err| switch (err) {
                            error.IncompatibleType => {
                                const tLeft = self.inferMachine.setTOvar.get(aS).?[0].?;
                                const tRight = self.inferMachine.setTOvar.get(bS).?[0].?;
                                Logger.logLocation.err(expr.token.?.loc, "To the left of this operation has {s} and to the right has {s}, they must be the same", .{ tLeft[0].token.?.tag.getName(), tRight[0].token.?.tag.getName() });

                                return null;
                            },
                            error.OutOfMemory => return error.OutOfMemory,
                        };
                    return aS;
                } else {
                    return b;
                }
            },
            else => {
                Logger.logLocation.err(expr.token.?.loc, "Node not supported {}", .{expr.tag});
                unreachable;
            },
        }

        unreachable;
    }

    fn checkExpressionExpectedType(self: *Self, expr: *Parser.Node, expectedType: Parser.Node) void {
        std.debug.assert(expectedType.tag == .type);
        std.debug.assert(Util.listContains(Parser.Node.Tag, &.{ .lit, .load, .neg, .parentesis, .power, .division, .multiplication, .subtraction, .addition }, expr.tag));

        switch (expr.tag) {
            .lit => {
                self.checkValueForType(expr.*, expectedType);
            },
            .load => {
                const variable = self.scopes.getLast().get(expr.token.?.getText(self.ast.source));

                if (variable) |v| {
                    const proto = self.ast.nodeList.items[v.data[0]];
                    if (proto.data[0] != 0) {
                        const t = self.ast.nodeList.items[proto.data[0]];

                        if (t.token.?.tag != expectedType.token.?.tag) {
                            Logger.logLocation.err(v.token.?.loc, "This variable declared here with type {s}", .{t.token.?.tag.getName()});
                            Logger.logLocation.err(expr.token.?.loc, "Is use here with another type {s}, these types are incompatible", .{expectedType.token.?.tag.getName()});
                            self.errs += 1;
                        }
                    } else {
                        self.inferMachine.found(v.*, expectedType, expr.token.?.loc);
                    }
                } else {
                    Logger.logLocation.err(expr.token.?.loc, "Unknown identifier in expression \"{s}\"", .{expr.token.?.getText(self.ast.source)});
                    self.errs += 1;
                }
            },
            .parentesis, .neg => {
                const left = &self.ast.nodeList.items[expr.data[0]];

                self.checkExpressionExpectedType(left, expectedType);
            },
            .addition, .subtraction, .multiplication, .division, .power => {
                const left = &self.ast.nodeList.items[expr.data[0]];
                const right = &self.ast.nodeList.items[expr.data[1]];

                self.checkExpressionExpectedType(left, expectedType);
                self.checkExpressionExpectedType(right, expectedType);
            },
            else => {
                Logger.logLocation.err(expr.token.?.loc, "Node not supported {}", .{expr.tag});
                unreachable;
            },
        }
    }

    fn checkValueForType(self: *Self, expr: Parser.Node, expectedType: Parser.Node) void {
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
    }
};

pub fn typeCheck(p: Parser.Ast) std.mem.Allocator.Error!bool {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();
    return try TypeChecker.init(alloc, p);
}
