const std = @import("std");
const Result = @import("Util.zig").Result;

pub const Arguments = struct { build: bool = false, run: bool = false, simulation: bool = false, silence: bool = false, bench: bool = false, path: []const u8 };
pub const ArgumentsError = struct {
    arg: ?[]const u8,
    err: anyerror,
};

pub fn parseArguments(args: [][]const u8) Result(Arguments, ArgumentsError) {
    const result = Result(Arguments, ArgumentsError);

    if (args.len == 0) {
        return result.Err(ArgumentsError{ .err = error.noSubcommandProvided, .arg = null });
    } else if (args.len == 1) {
        return result.Err(ArgumentsError{ .err = error.noFilePathProvided, .arg = null });
    }

    var a = Arguments{ .path = args[1] };

    parseSubcommand(args[0], &a) catch |err|
        return result.Err(ArgumentsError{ .err = err, .arg = args[0] });

    const arguments = args[2..];

    for (arguments) |arg| {
        parseArgument(arg, &a) catch |err|
            return result.Err(ArgumentsError{ .err = err, .arg = arg });
    }

    return result.Ok(a);
}

fn parseSubcommand(subcommand: []const u8, args: *Arguments) !void {
    if (std.mem.eql(u8, subcommand, "build")) {
        args.build = true;
    } else if (std.mem.eql(u8, subcommand, "run")) {
        args.build = true;
        args.run = true;
    } else if (std.mem.eql(u8, subcommand, "sim")) {
        args.simulation = true;
    } else {
        //std.debug.print("{s} unknown subcommand {s}\n\n", .{ message.Error, subcommand });
        return error.unknownSubcommand;
    }
}

fn parseArgument(arg: []const u8, args: *Arguments) !void {
    if (std.mem.eql(u8, arg, "-b")) {
        args.bench = true;
    } else if (std.mem.eql(u8, arg, "-s")) {
        args.silence = true;
    } else {
        //std.debug.print("{s} unknown argument {s}\n\n", .{ message.Error, arg });
        return error.unknownArgument;
    }
}

test {
    const result = Result(Arguments, ArgumentsError);

    var arg = std.ArrayList([]const u8).init(std.testing.allocator);
    defer arg.deinit();

    try std.testing.expect(std.meta.eql(parseArguments(arg.items), result{ .err = ArgumentsError{ .err = error.noSubcommandProvided, .arg = null } }));

    try arg.append("com");
    try std.testing.expect(std.meta.eql(parseArguments(arg.items), result{ .err = ArgumentsError{ .err = error.noFilePathProvided, .arg = null } }));

    try arg.append("f");
    try std.testing.expect(std.meta.eql(parseArguments(arg.items), result{ .err = ArgumentsError{ .err = error.unknownSubcommand, .arg = "com" } }));

    arg.clearRetainingCapacity();
    try arg.append("run");
    try arg.append("f");
    try arg.append("-f");
    try std.testing.expect(std.meta.eql(parseArguments(arg.items), result{ .err = ArgumentsError{ .err = error.unknownArgument, .arg = "-f" } }));

    arg.clearRetainingCapacity();
    try arg.append("run");
    try arg.append("f");
    try arg.append("-s");
    try arg.append("-b");
    try std.testing.expect(std.meta.eql(parseArguments(arg.items), result{ .ok = Arguments{ .path = "f", .build = true, .run = true, .bench = true, .silence = true } }));

    arg.clearRetainingCapacity();
    try arg.append("sim");
    try arg.append("f");
    try arg.append("-s");
    try arg.append("-b");
    try std.testing.expect(std.meta.eql(parseArguments(arg.items), result{ .ok = Arguments{ .path = "f", .simulation = true, .bench = true, .silence = true } }));
}

test {
    var a = Arguments{ .path = "f" };
    try std.testing.expectError(error.unknownSubcommand, parseSubcommand("-f", &a));

    try parseSubcommand("run", &a);
    try std.testing.expect(std.meta.eql(a, Arguments{ .path = "f", .run = true, .build = true }));

    a.build = false;
    a.run = false;

    try parseSubcommand("build", &a);
    try std.testing.expect(std.meta.eql(a, Arguments{ .path = "f", .build = true }));

    a.build = false;

    try parseSubcommand("sim", &a);
    try std.testing.expect(std.meta.eql(a, Arguments{ .path = "f", .simulation = true }));
}

test {
    var a = Arguments{ .path = "f" };
    try std.testing.expectError(error.unknownArgument, parseArgument("-f", &a));

    try parseArgument("-b", &a);
    try std.testing.expect(std.meta.eql(a, Arguments{ .path = "f", .bench = true }));
    a.bench = false;

    try parseArgument("-s", &a);
    try std.testing.expect(std.meta.eql(a, Arguments{ .path = "f", .silence = true }));
}
