const Lexer = @import("./../Lexer/Lexer.zig");

const Tag = enum {
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
    plus,
    minus,

    lit,
};

tag: Tag,
token: ?Lexer.Token,

// 0 is invalid beacause 0 is root
data: struct { usize, usize },
