const std = @import("std");
const util = @import("Util.zig");

pub const Arguments = struct {
    build: bool = false,
    stdout: bool = false,
    run: bool = false,
    simulation: bool = false,
    lex: bool = false,
    silence: bool = false,
    bench: bool = false,
    path: []const u8,
};

pub const ArgumentsError = error{
    noSubcommandProvided,
    noFilePathProvided,
    unknownSubcommand,
    unknownArgument,
};

const ArgError = util.ErrorPayLoad(ArgumentsError, ?[]const u8);
const ArgumentResult = util.Result(Arguments, ArgError);

pub fn parseArguments(args: [][]const u8) ArgumentResult {
    if (args.len == 0) {
        return ArgumentResult.Err(ArgError.init(error.noSubcommandProvided, null));
    } else if (args.len == 1) {
        return ArgumentResult.Err(ArgError.init(error.noFilePathProvided, null));
    }

    var a = Arguments{ .path = args[1] };

    parseSubcommand(args[0], &a) catch |err|
        return ArgumentResult.Err(ArgError.init(err, args[0]));

    const arguments = args[2..];

    for (arguments) |arg| {
        parseArgument(arg, &a) catch |err|
            return ArgumentResult.Err(ArgError.init(err, arg));
    }

    return ArgumentResult.Ok(a);
}

fn parseSubcommand(subcommand: []const u8, args: *Arguments) !void {
    if (std.mem.eql(u8, subcommand, "build")) {
        args.build = true;
    } else if (std.mem.eql(u8, subcommand, "run")) {
        args.build = true;
        args.run = true;
    } else if (std.mem.eql(u8, subcommand, "sim")) {
        args.simulation = true;
    } else if (std.mem.eql(u8, subcommand, "lex")) {
        args.lex = true;
    } else {
        return error.unknownSubcommand;
    }
}

fn parseArgument(arg: []const u8, args: *Arguments) !void {
    if (std.mem.eql(u8, arg, "-b")) {
        args.bench = true;
    } else if (std.mem.eql(u8, arg, "-s")) {
        args.silence = true;
    } else if (std.mem.eql(u8, arg, "-stdout")) {
        args.stdout = true;
    } else {
        return error.unknownArgument;
    }
}

test {
    var arg = std.ArrayList([]const u8).init(std.testing.allocator);
    defer arg.deinit();

    try std.testing.expect(std.meta.eql(parseArguments(arg.items), ArgumentResult{ .err = ArgError.init(error.noSubcommandProvided, null) }));
    try arg.append("com");
    try std.testing.expect(std.meta.eql(parseArguments(arg.items), ArgumentResult{ .err = ArgError.init(error.noFilePathProvided, null) }));

    try arg.append("f");
    try std.testing.expect(std.meta.eql(parseArguments(arg.items), ArgumentResult{ .err = ArgError.init(error.unknownSubcommand, "com") }));

    arg.clearRetainingCapacity();
    try arg.append("run");
    try arg.append("f");
    try arg.append("-f");
    try std.testing.expect(std.meta.eql(parseArguments(arg.items), ArgumentResult{ .err = ArgError.init(error.unknownArgument, "-f") }));

    arg.clearRetainingCapacity();
    try arg.append("run");
    try arg.append("f");
    try arg.append("-s");
    try arg.append("-b");
    try std.testing.expect(std.meta.eql(parseArguments(arg.items), ArgumentResult{ .ok = Arguments{ .path = "f", .build = true, .run = true, .bench = true, .silence = true } }));

    arg.clearRetainingCapacity();
    try arg.append("sim");
    try arg.append("f");
    try arg.append("-s");
    try arg.append("-b");
    try std.testing.expect(std.meta.eql(parseArguments(arg.items), ArgumentResult{ .ok = Arguments{ .path = "f", .simulation = true, .bench = true, .silence = true } }));
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

    a.simulation = false;

    try parseSubcommand("lex", &a);
    try std.testing.expect(std.meta.eql(a, Arguments{ .path = "f", .lex = true }));
}

test {
    var a = Arguments{ .path = "f" };
    try std.testing.expectError(error.unknownArgument, parseArgument("-f", &a));

    try parseArgument("-b", &a);
    try std.testing.expect(std.meta.eql(a, Arguments{ .path = "f", .bench = true }));
    a.bench = false;

    try parseArgument("-s", &a);
    try std.testing.expect(std.meta.eql(a, Arguments{ .path = "f", .silence = true }));

    a.silence = false;
    try parseArgument("-stdout", &a);
    try std.testing.expect(std.meta.eql(a, Arguments{ .path = "f", .stdout = true }));
}
