const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn Result(comptime Success: type, comptime Error: type) type {
    return union(enum) {
        err: Error,
        ok: Success,

        pub fn Err(e: Error) Result(Success, Error) {
            return Result(Success, Error){ .err = e };
        }

        pub fn Ok(s: Success) Result(Success, Error) {
            return Result(Success, Error){ .ok = s };
        }
    };
}

pub fn listContains(t: type, l: []const t, e: t) bool {
    for (l) |s| {
        if (e == s) {
            return true;
        }
    }
    return false;
}

pub fn ErrorPayLoad(comptime Error: type, comptime PayLoad: type) type {
    return struct {
        err: Error,
        payload: PayLoad,

        pub fn init(err: Error, payload: PayLoad) ErrorPayLoad(Error, PayLoad) {
            return ErrorPayLoad(Error, PayLoad){ .err = err, .payload = payload };
        }
    };
}

pub const Command = struct {
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
};
