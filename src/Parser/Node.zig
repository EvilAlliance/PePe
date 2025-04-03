const Lexer = @import("./../Lexer/Lexer.zig");

pub const Tag = enum {
    root,

    empty,

    funcDecl,
    funcProto,
    args,
    type,

    scope,

    // Right must be free for the index of next statement
    ret,
    variable, // left variable prot
    constant, // left variable Proto
    VarProto, //left tyep, right expr

    //expresion
    addition,
    subtraction,
    multiplication,
    division,
    power,
    parentesis,
    neg,
    get,

    lit,
};

tag: Tag,
token: ?Lexer.Token,

// 0 is invalid beacause 0 is root
data: struct { usize, usize },
