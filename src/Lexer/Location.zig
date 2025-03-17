path: []const u8,
content: []const u8,
row: u64,
col: u64,
i: u64,

pub fn print(self: @This(), p: *const fn (comptime format: []const u8, args: anytype) void) void {
    var beg = self.i;

    while (beg > 1 and self.content[beg - 1] != '\n') : (beg -= 1) {}
    beg -= 1;

    var end = self.i;

    while (end < self.content.len and self.content[end + 1] != '\n') : (end += 1) {}
    end += 1;

    p("{s}\n", .{self.content[beg..end]});
}
