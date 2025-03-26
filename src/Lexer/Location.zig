const Lexer = @import("Lexer.zig");
const PrettyLocation = Lexer.PrettyLocation;

start: usize,
end: usize,

var lastPretyLocation: ?struct { @This(), PrettyLocation } = null;

pub fn getPrettyLocation(self: @This(), path: []const u8, source: [:0]const u8) PrettyLocation {
    var start: usize = 0;
    var prettyLocation = PrettyLocation{
        .path = path,
        .row = 1,
        .col = 1,
    };
    if (lastPretyLocation) |x| {
        const loc, const pret = x;
        start = loc.start;
        prettyLocation = pret;
    }

    while (start < source.len and start < self.start) {
        if (source[start] == '\n') {
            prettyLocation.row += 1;
            prettyLocation.col = 0;
        }

        prettyLocation.col += 1;
        start += 1;
    }

    lastPretyLocation = .{ self, prettyLocation };

    return prettyLocation;
}

pub fn getText(self: @This(), source: []const u8) []const u8 {
    return source[self.start..self.end];
}
