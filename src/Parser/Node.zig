const Lexer = @import("./../Lexer/Lexer.zig");

pub const Tag = enum {
    root,

    funcDecl,
    funcProto,
    args,
    type,

    // Body of anything or scope
    body,

    //statements
    ret,

    //expresion
    addition,
    subtraction,
    multiplication,
    division,
    power,
    parentesis,
    neg,

    lit,
};

tag: Tag,
token: ?Lexer.Token,

// 0 is invalid beacause 0 is root
data: struct { usize, usize },
