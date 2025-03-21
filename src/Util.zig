const std = @import("std");

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
