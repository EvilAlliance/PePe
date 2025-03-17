const std = @import("std");
const Allocator = std.mem.Allocator;

alloc: Allocator,
command: []const []const u8,
pipe: bool,
stdout: []u8,
stderr: []u8,

pub fn init(alloc: Allocator, command: []const []const u8, pipe: bool) @This() {
    return @This(){
        .alloc = alloc,
        .command = command,
        .pipe = pipe,
        .stdout = "",
        .stderr = "",
    };
}

pub fn execute(self: *@This()) !std.process.Child.Term {
    var exec = std.process.Child.init(self.command, self.alloc);

    if (self.pipe) {
        exec.stdout_behavior = .Pipe;
        exec.stderr_behavior = .Pipe;

        try exec.spawn();

        self.stdout = try exec.stdout.?.reader().readAllAlloc(self.alloc, std.math.maxInt(u64));
        self.stderr = try exec.stderr.?.reader().readAllAlloc(self.alloc, std.math.maxInt(u64));
    } else {
        exec.stdout_behavior = .Ignore;
        exec.stderr_behavior = .Ignore;

        try exec.spawn();
    }

    return try exec.wait();
}
