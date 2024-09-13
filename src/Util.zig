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
