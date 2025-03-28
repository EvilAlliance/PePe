const Lexer = @import("Lexer.zig");
const PrettyLocation = Lexer.PrettyLocation;

path: []const u8,
content: [:0]const u8,

row: usize,
col: usize,

start: usize,
end: usize,

pub fn getText(self: @This(), source: []const u8) []const u8 {
    return source[self.start..self.end];
}

pub fn shallowCopy(self: @This(), start: usize, end: usize) @This() {
    var new = self;
    new.start = start;
    new.end = end;

    return new;
}

pub fn init(path: []const u8, content: [:0]const u8) @This() {
    return @This(){
        .path = path,
        .content = content,

        .col = 1,
        .row = 1,

        .start = undefined,
        .end = undefined,
    };
}
