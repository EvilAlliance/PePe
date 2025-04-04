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
    ret, // left expression
    variable, // left variable Prot
    constant, // left variable Proto
    VarProto, //left type, right expr

    //expresion
    addition,
    subtraction,
    multiplication,
    division,
    power,
    parentesis,
    neg,
    load,

    lit,
};

tag: Tag,
token: ?Lexer.Token,

// 0 is invalid beacause 0 is root
data: struct { usize, usize },
