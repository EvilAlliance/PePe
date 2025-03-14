const c = @cImport({
    @cInclude("stdio.h");
});

////////////////////////////////
// Prelude.h
////////////////////////////////
// just represents some region of bytes, usually in file parsing crap
pub const Slice = extern struct {
    data: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    length: usize = @import("std").mem.zeroes(usize),
};

pub const WindowsSubsystem = enum(c_int) {
    UNKNOWN,
    WINDOWS,
    CONSOLE,
    EFI_APP,
};

pub const OutputFlavor = enum(c_int) {
    OBJECT, // .o  .obj
    SHARED, // .so .dll
    STATIC, // .a  .lib
    EXECUTABLE, //     .exe
};

pub const ExecutableType = enum(c_int) {
    UNKNOWN,
    PE,
    ELF,
};

pub const Arch = enum(c_int) {
    UNKNOWN,

    X86_64,
    AARCH64,

    // they're almost identical so might as well do both.
    MIPS32,
    MIPS64,

    WASM32,

    MAX,
};

pub const System = enum(c_int) {
    WINDOWS,
    LINUX,
    MACOS,
    ANDROID, // Not supported yet
    WASM,

    MAX,
};

pub const ABI = enum(c_int) {
    // Used on 64bit Windows platforms
    WIN64,

    // Used on Mac, BSD and Linux platforms
    SYSTEMV,
};

pub const Emitter = extern struct {
    capacity: usize = @import("std").mem.zeroes(usize),
    count: usize = @import("std").mem.zeroes(usize),
    data: [*c]u8 = @import("std").mem.zeroes([*c]u8),
};

pub const outReserve = @extern(*const fn (o: [*c]Emitter, count: usize) callconv(.C) ?*anyopaque, .{ .name = "tb_out_reserve" });
pub const outCommit = @extern(*const fn (o: [*c]Emitter, count: usize) callconv(.C) void, .{ .name = "tb_out_commit" });

// reserves & commits
pub const outGrab = @extern(*const fn (o: [*c]Emitter, count: usize) callconv(.C) ?*anyopaque, .{ .name = "tb_out_grab" });
pub const outGrabI = @extern(*const fn (o: [*c]Emitter, count: usize) callconv(.C) usize, .{ .name = "tb_out_grab_i" });
pub const outGetPos = @extern(*const fn (o: [*c]Emitter, p: ?*anyopaque) callconv(.C) usize, .{ .name = "tb_out_get_pos" });

// Adds null terminator onto the end and returns the starting position of the string
pub const outstrNulUNSAFE = @extern(*const fn (o: [*c]Emitter, str: [*c]const u8) callconv(.C) usize, .{ .name = "tb_outstr_nul_UNSAFE" });

pub const out1bUNSAFE = @extern(*const fn (o: [*c]Emitter, i: u8) callconv(.C) void, .{ .name = "tb_out1b_UNSAFE" });
pub const out4bUNSAFE = @extern(*const fn (o: [*c]Emitter, i: u32) callconv(.C) void, .{ .name = "tb_out4b_UNSAFE" });
pub const outstrUNSAFE = @extern(*const fn (o: [*c]Emitter, str: [*c]const u8) callconv(.C) void, .{ .name = "tb_outstr_UNSAFE" });
pub const outsUNSAFE = @extern(*const fn (o: [*c]Emitter, len: usize, str: ?*const anyopaque) callconv(.C) void, .{ .name = "tb_outs_UNSAFE" });

pub const outs = @extern(*const fn (o: [*c]Emitter, len: usize, str: ?*const anyopaque) callconv(.C) usize, .{ .name = "tb_outs" });
pub const outGet = @extern(*const fn (o: [*c]Emitter, pos: usize) callconv(.C) ?*anyopaque, .{ .name = "tb_out_get" });

// fills region with zeros
pub const outZero = @extern(*const fn (o: [*c]Emitter, len: usize) callconv(.C) void, .{ .name = "tb_out_zero" });

pub const out1b = @extern(*const fn (o: [*c]Emitter, i: u8) callconv(.C) void, .{ .name = "tb_out1b" });

pub const out2b = @extern(*const fn (o: [*c]Emitter, i: u16) callconv(.C) void, .{ .name = "tb_out2b" });
pub const out4b = @extern(*const fn (o: [*c]Emitter, i: u32) callconv(.C) void, .{ .name = "tb_out4b" });
pub const out8b = @extern(*const fn (o: [*c]Emitter, i: u64) callconv(.C) void, .{ .name = "tb_out8b" });
pub const patch1b = @extern(*const fn (o: [*c]Emitter, pos: u32, i: u8) callconv(.C) void, .{ .name = "tb_patch1b" });
pub const patch2b = @extern(*const fn (o: [*c]Emitter, pos: u32, i: u16) callconv(.C) void, .{ .name = "tb_patch2b" });
pub const patch4b = @extern(*const fn (o: [*c]Emitter, pos: u32, i: u32) callconv(.C) void, .{ .name = "tb_patch4b" });
pub const patch8b = @extern(*const fn (o: [*c]Emitter, pos: u32, i: u64) callconv(.C) void, .{ .name = "tb_patch8b" });

pub const get1b = @extern(*const fn (o: [*c]Emitter, pos: u32) callconv(.C) u8, .{ .name = "tb_get1b" });
pub const get2b = @extern(*const fn (o: [*c]Emitter, pos: u32) callconv(.C) u16, .{ .name = "tb_get2b" });
pub const get4b = @extern(*const fn (o: [*c]Emitter, pos: u32) callconv(.C) u32, .{ .name = "tb_get4b" });
////////////////////////////////
// tb.h
////////////////////////////////

// Glossary (because i don't know where else to put it)
//   IR   - Intermediate Representation
//   SoN  - Sea Of Nodes (https://www.oracle.com/technetwork/java/javase/tech/c2-ir95-150110.pdf)
//   SSA  - Single Static Assignment
//   VN   - Value Number
//   GVN  - Global Value Numbering
//   CSE  - Common Subexpression Elimination
//   CFG  - Control Flow Graph
//   DSE  - Dead Store Elimination
//   GCM  - Global Code Motion
//   SROA - Scalar Replacement Of Aggregates
//   CCP  - Conditional Constant Propagation
//   SCCP - Sparse Conditional Constant Propagation
//   RPO  - Reverse PostOrder
//   RA   - Register Allocation
//   BB   - Basic Block
//   ZTC  - Zero Trip Count
//   MAF  - Monotone Analysis Framework
//   SCC  - Strongly Connected Components
//   MOP  - Meet Over all Paths
//   IPO  - InterProcedural Optimizations
//   RPC  - Return Program Counter

////////////////////////////////
// Flags
////////////////////////////////
pub const ArithmeticBehavior = enum(c_int) {
    NONE = 0,
    NSW = 1,
    NUW = 2,
};

pub const DebugFormat = enum(c_int) {
    NONE = 0,
    DWARF = 1,
    CODEVIEW = 2,
    SDG = 3,
};

pub const CallingConv = enum(c_int) {
    CDECL,
    STDCALL,
};

pub const FeatureSet_X64 = enum(c_int) {
    SSE2 = (@as(u32, 1) << @as(u32, 0)),
    SSE3 = (@as(u32, 1) << @as(u32, 1)),
    SSE41 = (@as(u32, 1) << @as(u32, 2)),
    SSE42 = (@as(u32, 1) << @as(u32, 3)),

    POPCNT = (@as(u32, 1) << @as(u32, 4)),
    LZCNT = (@as(u32, 1) << @as(u32, 5)),

    CLMUL = (@as(u32, 1) << @as(u32, 6)),
    F16C = (@as(u32, 1) << @as(u32, 7)),

    BMI1 = (@as(u32, 1) << @as(u32, 8)),
    BMI2 = (@as(u32, 1) << @as(u32, 9)),

    AVX = (@as(u32, 1) << @as(u32, 10)),
    AVX2 = (@as(u32, 1) << @as(u32, 11)),
};

pub const FeatureSet_Generic = enum(c_int) {
    FRAME_PTR = (@as(u32, 1) << @as(u32, 0)),
};

pub const FeatureSet = extern struct {
    gen: u32, // TB_FeatureSet_Generic
    x64: u32, // TB_FeatureSet_X64
};

pub const Linkage = enum(c_int) {
    PUBLIC,
    PRIVATE,
};

pub const ComdatType = enum(c_int) {
    NONE,
    MATCH_ANY,
};
pub const MemoryOrder = enum(c_int) {
    // atomic ops, unordered
    RELAXED,

    // acquire for loads:
    //   loads/stores from after this load cannot be reordered
    //   after this load.
    //
    // release for stores:
    //   loads/stores from before this store on this thread
    //   can't be reordered after this store.
    ACQ_REL,

    // acquire, release and total order across threads.
    SEQ_CST,
};

pub const DataTypeTag = enum(u4) {
    VOID,
    // Boolean
    BOOL,
    // Integers
    I8,
    I16,
    I32,
    I64,
    // Pointers
    PTR,
    // Floating point numbers
    F32,
    F64,
    // SIMD vectors, note that not all sizes are supported on all
    // platforms (unlike every other type)
    V64,
    V128,
    V256,
    V512,
    // Control token
    CONTROL,
    // memory effects (and I/O), you can think of it like a giant magic table of
    // all memory addressed with pointers.
    MEMORY,
    // Tuples, these cannot be used in memory ops, just accessed via projections
    TUPLE,
};

pub const DataType = extern union {
    x: packed struct {
        type: DataTypeTag,
        // for vectors, it's the element type.
        // for pointers, it's the address space (there's currently only one but
        // once GCs and funky hardware are introduced this will matter).
        elem_or_addrspace: u4,
    },
    raw: u8,
};

// classify data types
pub inline fn isVoidType(x: anytype) @TypeOf(x.type == DataTypeTag.VOID) {
    _ = &x;
    return x.type == DataTypeTag.VOID;
}
pub inline fn isBoolType(x: anytype) @TypeOf(x.type == DataTypeTag.BOOL) {
    _ = &x;
    return x.type == DataTypeTag.BOOL;
}
pub inline fn isIntegerType(x: anytype) @TypeOf((x.type >= DataTypeTag.I8) and (x.type <= DataTypeTag.I64)) {
    _ = &x;
    return (x.type >= DataTypeTag.I8) and (x.type <= DataTypeTag.I64);
}
pub inline fn isFloatType(x: anytype) @TypeOf((x.type == DataTypeTag.F32) or (x.type == DataTypeTag.F64)) {
    _ = &x;
    return (x.type == DataTypeTag.F32) or (x.type == DataTypeTag.F64);
}
pub inline fn isPointerType(x: anytype) @TypeOf(x.type == DataTypeTag.PTR) {
    _ = &x;
    return x.type == DataTypeTag.PTR;
}
pub inline fn isScalarType(x: anytype) @TypeOf(x.type <= DataTypeTag.F64) {
    _ = &x;
    return x.type <= DataTypeTag.F64;
}
pub inline fn isIntOrPointer(x: anytype) @TypeOf((x.type >= DataTypeTag.I8) and (x.type <= DataTypeTag.PTR)) {
    _ = &x;
    return (x.type >= DataTypeTag.I8) and (x.type <= DataTypeTag.PTR);
}

// accessors
pub inline fn getIntBandWith(x: anytype) @TypeOf(x.data) {
    _ = &x;
    return x.data;
}
pub inline fn getFloatFotmat(x: anytype) @TypeOf(x.data) {
    _ = &x;
    return x.data;
}
pub inline fn getPtrAddespace(x: anytype) @TypeOf(x.data) {
    _ = &x;
    return x.data;
}

////////////////////////////////
// ANNOTATIONS
////////////////////////////////
//
//   (A, B) -> (C, D)
//
//   node takes A and B, produces C, D. if there's multiple
//   results we need to use projections and the indices are
//   based on the order seen here, proj0 is C, proj1 is D.
//
//   (A, B) & C -> Int
//
//   nodes takes A and B along with C in it's extra data. this is
//   where non-node inputs fit.
//
pub const NodeTypeEnum = enum(c_int) {
    NULL = 0,

    ////////////////////////////////
    // CONSTANTS
    ////////////////////////////////
    ICONST,
    F32CONST,
    F64CONST,

    ////////////////////////////////
    // PROJECTIONS
    ////////////////////////////////
    // projections just extract a single field of a tuple
    PROJ, // Tuple & Int -> Any
    // control projection for TB_BRANCH
    BRANCH_PROJ, // Branch & Int -> Control
    // this is a hack for me to add nodes which need to be scheduled directly
    // after a tuple (like a projection) but don't really act like projections
    // in any other context.
    MACH_PROJ, // (T) & Index -> T

    ////////////////////////////////
    // MISCELLANEOUS
    ////////////////////////////////
    // this is an unspecified value, usually generated by the optimizer
    // when malformed input is folded into an operation.
    POISON, // () -> Any
    // this is a simple way to embed machine code into the code
    INLINE_ASM, // (Control, Memory) & InlineAsm -> (Control, Memory)
    // reads the TSC on x64
    CYCLE_COUNTER, // (Control) -> Int64
    // prefetches data for reading. The number next to the
    //
    //   0   is temporal
    //   1-3 are just cache levels
    PREFETCH, // (Memory, Ptr) & Int -> Memory
    // this is a bookkeeping node for constructing IR while optimizing, so we
    // don't keep track of nodes while running peeps.
    SYMBOL_TABLE,

    ////////////////////////////////
    // CONTROL
    ////////////////////////////////
    //   there's only one ROOT per function, it's inputs are the return values, it's
    //   outputs are the initial params.
    ROOT, // (Callgraph, Exits...) -> (Control, Memory, RPC, Data...)
    //   return nodes feed into ROOT, jumps through the RPC out of this stack frame.
    RETURN, // (Control, Memory, RPC, Data...) -> ()
    //   regions are used to represent paths which have multiple entries.
    //   each input is a predecessor.
    REGION, // (Control...) -> (Control)
    //   a natural loop header has the first edge be the dominating predecessor, every other edge
    //   is a backedge.
    NATURAL_LOOP, // (Control...) -> (Control)
    //   a natural loop header (thus also a region) with an affine induction var (and thus affine loop bounds)
    AFFINE_LOOP, // (Control...) -> (Control)
    //   phi nodes work the same as in SSA CFG, the value is based on which predecessor was taken.
    //   each input lines up with the regions such that region.in[i] will use phi.in[i+1] as the
    //   subsequent data.
    PHI, // (Control, Data...) -> Data
    //   branch is used to implement most control flow, it acts like a switch
    //   statement in C usually. they take a key and match against some cases,
    //   if they match, it'll jump to that successor, if none match it'll take
    //   the default successor.
    //
    //   if (cond) { A; } else { B; }    is just     switch (cond) { case 0: B; default: A; }
    //
    //   it's possible to not pass a key and the default successor is always called, this is
    //   a GOTO. tb_inst_goto, tb_inst_if can handle common cases for you.
    BRANCH, // (Control, Data) -> (Control...)
    //   just a branch but tagged as the latch to some affine loop.
    AFFINE_LATCH, // (Control, Data) -> (Control...)
    //   this is a fake branch which acts as a backedge for infinite loops, this keeps the
    //   graph from getting disconnected with the endpoint.
    //
    //   CProj0 is the taken path, CProj1 is exits the loop.
    NEVER_BRANCH, // (Control) -> (Control...)
    //   this is a fake branch that lets us define multiple entry points into the function for whatever
    //   reason.
    TB_ENTRY_FORK,
    //   debugbreak will trap in a continuable manner.
    DEBUGBREAK, // (Control, Memory) -> (Control)
    //   trap will not be continuable but will stop execution.
    TRAP, // (Control, Memory) -> (Control)
    //   unreachable means it won't trap or be continuable.
    UNREACHABLE, // (Control, Memory) -> (Control)
    //   all dead paths are stitched here
    DEAD, // (Control) -> (Control)

    ////////////////////////////////
    // CONTROL + MEMORY
    ////////////////////////////////
    //   nothing special, it's just a function call, 3rd argument here is the
    //   target pointer (or syscall number) and the rest are just data args.
    CALL, // (Control, Memory, Ptr, Data...) -> (Control, Memory, Data)
    SYSCALL, // (Control, Memory, Ptr, Data...) -> (Control, Memory, Data)
    //   performs call while recycling the stack frame somewhat
    TAILCALL, // (Control, Memory, RPC, Data, Data...) -> ()
    //   this is a safepoint used for traditional C debugging, each of these nodes
    //   annotates a debug line location.
    DEBUG_LOCATION, // (Control, Memory) -> (Control, Memory)
    SAFEPOINT, // (Control, Memory, Node, Data...) -> (Control)
    //   this special op tracks calls such that we can produce our cool call graph, there's
    //   one call graph node per function that never moves.
    CALLGRAPH, // (Call...) -> Void
    DEBUG_SCOPES, // (Parent, Control...)

    ////////////////////////////////
    // MEMORY
    ////////////////////////////////
    //   produces a set of non-aliasing memory effects
    SPLITMEM, // (Memory) -> (Memory...)
    //   MERGEMEM will join multiple non-aliasing memory effects, because
    //   they don't alias there's no ordering guarentee.
    MERGEMEM, // (Split, Memory...) -> Memory
    //   LOAD and STORE are standard memory accesses, they can be folded away.
    LOAD, // (Control?, Memory, Ptr)      -> Data
    STORE, // (Control, Memory, Ptr, Data) -> Memory
    //   bulk memory ops.
    MEMCPY, // (Control, Memory, Ptr, Ptr, Size)  -> Memory
    MEMSET, // (Control, Memory, Ptr, Int8, Size) -> Memory
    //   these memory accesses represent "volatile" which means
    //   they may produce side effects and thus cannot be eliminated.
    READ, // (Control, Memory, Ptr)       -> (Memory, Data)
    WRITE, // (Control, Memory, Ptr, Data) -> (Memory, Data)
    //   atomics have multiple observers (if not they wouldn't need to
    //   be atomic) and thus produce side effects everywhere just like
    //   volatiles except they have synchronization guarentees. the atomic
    //   data ops will return the value before the operation is performed.
    //   Atomic CAS return the old value and a boolean for success (true if
    //   the value was changed)
    ATOMIC_LOAD, // (Control, Memory, Ptr)        -> (Memory, Data)
    ATOMIC_XCHG, // (Control, Memory, Ptr, Data)  -> (Memory, Data)
    ATOMIC_ADD, // (Control, Memory, Ptr, Data)  -> (Memory, Data)
    ATOMIC_AND, // (Control, Memory, Ptr, Data)  -> (Memory, Data)
    ATOMIC_XOR, // (Control, Memory, Ptr, Data)  -> (Memory, Data)
    ATOMIC_OR, // (Control, Memory, Ptr, Data)  -> (Memory, Data)
    ATOMIC_PTROFF, // (Control, Memory, Ptr, Ptr)   -> (Memory, Ptr)
    ATOMIC_CAS, // (Control, Memory, Data, Data) -> (Memory, Data, Bool)

    // like a multi-way branch but without the control flow aspect, but for data.
    LOOKUP,

    ////////////////////////////////
    // POINTERS
    ////////////////////////////////
    //   LOCAL will statically allocate stack space
    LOCAL, // () & (Int, Int) -> Ptr
    //   SYMBOL will return a pointer to a TB_Symbol
    SYMBOL, // () & TB_Symbol* -> Ptr
    //   offsets pointer by byte amount (handles all ptr math you actually want)
    PTR_OFFSET, // (Ptr, Int) -> Ptr

    // Conversions
    TRUNCATE,
    FLOAT_TRUNC,
    FLOAT_EXT,
    SIGN_EXT,
    ZERO_EXT,
    UINT2FLOAT,
    FLOAT2UINT,
    INT2FLOAT,
    FLOAT2INT,
    BITCAST,

    // Select
    SELECT,

    // Bitmagic
    BSWAP,
    CLZ,
    CTZ,
    POPCNT,

    // Unary operations
    FNEG,

    // Integer arithmatic
    AND,
    OR,
    XOR,
    ADD,
    SUB,
    MUL,

    SHL,
    SHR,
    SAR,
    ROL,
    ROR,
    UDIV,
    SDIV,
    UMOD,
    SMOD,

    // Float arithmatic
    FADD,
    FSUB,
    FMUL,
    FDIV,
    FMIN,
    FMAX,

    // Comparisons
    CMP_EQ,
    CMP_NE,
    CMP_ULT,
    CMP_ULE,
    CMP_SLT,
    CMP_SLE,
    CMP_FLT,
    CMP_FLE,

    FRAME_PTR,

    // Special ops
    //   add with carry
    ADC, // (Int, Int, Bool?) -> (Int, Bool)
    //   division and modulo
    UDIVMOD, // (Int, Int) -> (Int, Int)
    SDIVMOD, // (Int, Int) -> (Int, Int)
    //   does full multiplication (64x64=128 and so on) returning
    //   the low and high values in separate projections
    MULPAIR,

    // variadic
    VA_START,

    // x86 intrinsics
    X86INTRIN_LDMXCSR,
    X86INTRIN_STMXCSR,
    X86INTRIN_SQRT,
    X86INTRIN_RSQRT,

    // general machine nodes:
    // does the phi move
    MACH_MOVE,
    MACH_COPY,
    // (Control) -> Control
    MACH_JUMP,
    // just... it, idk, it's the frame ptr
    MACH_FRAME_PTR,
    // thread-local JIT context
    MACH_JIT_THREAD_PTR,
    // isn't the pointer value itself, just a placeholder for
    // referring to a global.
    MACH_SYMBOL,

    // limit on generic nodes
    NODE_TYPE_MAX,

    // each family of machine nodes gets 256 nodes
    // first machine op, we have some generic ops here:
    MACH_X86 = @intFromEnum(Arch.X86_64) * 0x100,
    MACH_A64 = @intFromEnum(Arch.AARCH64) * 0x100,
    MACH_MIPS = @intFromEnum(Arch.MIPS32) * 0x100,
};
pub const NodeType = u16;

// represents byte counts
pub const CharUnits = u32;

// will get interned so each TB_Module has a unique identifier for the source file
pub const SourceFile = extern struct {
    // used by the debug info export
    id: c_int align(8) = @import("std").mem.zeroes(c_int),
    len: usize = @import("std").mem.zeroes(usize),
    pub fn path(self: anytype) @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8) {
        const Intermediate = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        const ReturnType = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 16)));
    }
};

pub const Location = extern struct {
    file: [*c]SourceFile = @import("std").mem.zeroes([*c]SourceFile),
    line: c_int = @import("std").mem.zeroes(c_int),
    column: c_int = @import("std").mem.zeroes(c_int),
    pos: u32 = @import("std").mem.zeroes(u32),
};

// SO refers to shared objects which mean either shared libraries (.so or .dll)
// or executables (.exe or ELF executables)
pub const ExternalType = enum(c_int) {
    // exports to the rest of the shared object
    SO_LOCAL,

    // exports outside of the shared object
    SO_EXPORT,
};

pub const Global = opaque {};
pub const External = opaque {};
pub const Function = opaque {};

pub const Module = opaque {};
pub const DebugType = opaque {};
pub const ModuleSection = opaque {};

// TODO(NeGate): get rid of the lack of namespace here
pub const RegMask = opaque {};

pub const ModuleSectionHandleNone = -1;
pub const ModuleSectionHandle = i32;
pub const Attrib = opaque {};

// target-specific, just a unique ID for the registers
pub const PhysicalReg = c_int;

// Thread local module state
pub const ThreadInfo = opaque {};

pub const SymbolTag = enum(c_int) {
    NONE,
    EXTERNAL,
    GLOBAL,
    FUNCTION,
    MAX,
};

// Refers generically to objects within a module
//
// TB_Function, TB_Global, and TB_External are all subtypes of TB_Symbol
// and thus are safely allowed to cast into a symbol for operations.
pub const Symbol = extern struct {
    tag: SymbolTag = @import("std").mem.zeroes(SymbolTag),
    linkage: Linkage = @import("std").mem.zeroes(Linkage),

    // which thread info it's tied to (we may need to remove it, this
    // is used for that)
    info: ?*ThreadInfo = @import("std").mem.zeroes(?*ThreadInfo),

    name_length: usize = @import("std").mem.zeroes(usize),
    name: [*c]u8 = @import("std").mem.zeroes([*c]u8),

    // It's kinda a weird circular reference but yea
    module: ?*Module = @import("std").mem.zeroes(?*Module),

    // helpful for sorting and getting consistent builds
    ordinal: u64 = @import("std").mem.zeroes(u64),
    unnamed_0: SymbolUnion = @import("std").mem.zeroes(SymbolUnion),
};

const SymbolUnion = extern union {
    // if we're JITing then this maps to the address of the symbol
    address: ?*anyopaque,
    symbol_id: usize,
};

pub const User = packed struct {
    _n: u48,
    _slot: u16,
};

pub const Node = extern struct {
    type: NodeType align(8) = @import("std").mem.zeroes(NodeType),
    dt: DataType = @import("std").mem.zeroes(DataType),

    input_cap: u16 = @import("std").mem.zeroes(u16),
    input_count: u16 = @import("std").mem.zeroes(u16),

    user_cap: u16 = @import("std").mem.zeroes(u16),
    user_count: u16 = @import("std").mem.zeroes(u16),

    // makes it easier to track in graph walks
    gvn: u32 = @import("std").mem.zeroes(u32),
    // def-use edges, unordered
    users: ?*User = @import("std").mem.zeroes(?*User),
    // ordered use-def edges, jolly ol' semantics.
    //   after input_count (and up to input_cap) goes an unordered set of nodes which
    //   act as extra deps, this is where anti-deps and other scheduling related edges
    //   are placed. stole this trick from Cliff... ok if you look at my compiler impl
    //   stuff it's either gonna be like trad compiler stuff, Cnile, LLVM or Cliff that's
    //   just how i learned :p
    inputs: [*c]?*Node = @import("std").mem.zeroes([*c]?*Node),
    pub fn extra(self: anytype) @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8) {
        const Intermediate = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        const ReturnType = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 32)));
    }
};

// These are the extra data in specific nodes
pub inline fn nodeGetExtra(n: *Node) ?*anyopaque {
    return n.extra;
}
pub inline fn nodeGetExtraT(n: *Node, T: type) ?*T {
    return @as(?*T, n.extra);
}
pub inline fn nodeSetExtra(n: *Node, T: type, args: T) void {
    const value = T{args};
    const ptr = @as(*T, n.extra);
    ptr.* = value;
}

// this represents switch (many targets), if (one target)
pub const NodeBranch = extern struct { // TB_BRANCH
    total_hits: u64 = @import("std").mem.zeroes(u64),
    succ_count: usize = @import("std").mem.zeroes(usize),
};

pub const NodeMachCopy = extern struct { // TB_MACH_COPY
    use: ?*RegMask = @import("std").mem.zeroes(?*RegMask),
    def: ?*RegMask = @import("std").mem.zeroes(?*RegMask),
};

pub const _NodeProj = extern struct { // TB_PROJ
    index: c_int = @import("std").mem.zeroes(c_int),
};

pub const NodeSymbolTable = extern struct { // TB_SYMBOL_TABLE
    complete: bool = @import("std").mem.zeroes(bool),
};

pub const NodeMachProj = extern struct { // TB_MACH_PROJ
    index: c_int = @import("std").mem.zeroes(c_int),
    def: ?*RegMask = @import("std").mem.zeroes(?*RegMask),
};

pub const NodeMachSymbol = extern struct { // TB_MACH_SYMBOL
    sym: [*c]Symbol = @import("std").mem.zeroes([*c]Symbol),
};

pub const NodeBranchProj = extern struct { // TB_BRANCH_PROJ
    index: c_int = @import("std").mem.zeroes(c_int),
    taken: u64 = @import("std").mem.zeroes(u64),
    key: i64 = @import("std").mem.zeroes(i64),
};

pub const NodeInt = extern struct { // TB_ICONST
    value: u64 = @import("std").mem.zeroes(u64),
};

pub const NodeCompare = extern struct { // any compare operator
    cmp_dt: DataType = @import("std").mem.zeroes(DataType),
};

pub const NodeBinopInt = extern struct { // any integer binary operator
    ab: ArithmeticBehavior = @import("std").mem.zeroes(ArithmeticBehavior),
};

pub const NodeMemAccess = extern struct {
    @"align": CharUnits = @import("std").mem.zeroes(CharUnits),
};

pub const NodeDbgLoc = extern struct { // TB_DEBUG_LOCATION
    file: [*c]SourceFile = @import("std").mem.zeroes([*c]SourceFile),
    line: c_int = @import("std").mem.zeroes(c_int),
    column: c_int = @import("std").mem.zeroes(c_int),
};

pub const NodePrefetch = extern struct {
    level: c_int = @import("std").mem.zeroes(c_int),
};

pub const NodeLocal = extern struct {
    size: CharUnits = @import("std").mem.zeroes(CharUnits),
    @"align": CharUnits = @import("std").mem.zeroes(CharUnits),

    has_split: bool = @import("std").mem.zeroes(bool),

    // used when machine-ifying it
    stack_pos: c_int = @import("std").mem.zeroes(c_int),

    // dbg info
    name: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    type: ?*DebugType = @import("std").mem.zeroes(?*DebugType),
};

pub const NodeFloat32 = extern struct {
    value: f32 = @import("std").mem.zeroes(f32),
};

pub const NodeFloat64 = extern struct {
    value: f64 = @import("std").mem.zeroes(f64),
};
pub const NodeSymbol = extern struct {
    sym: [*c]Symbol = @import("std").mem.zeroes([*c]Symbol),
};
pub const NodeAtomic = extern struct {
    order: MemoryOrder = @import("std").mem.zeroes(MemoryOrder),
    order2: MemoryOrder = @import("std").mem.zeroes(MemoryOrder),
};
pub const NodeSafepoint = extern struct {
    userdata: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    // all the saved values are at the end of the input list
    saved_val_count: c_int = @import("std").mem.zeroes(c_int),
};

pub const NodeCall = extern struct {
    super: NodeSafepoint = @import("std").mem.zeroes(NodeSafepoint),
    proto: [*c]FunctionPrototype = @import("std").mem.zeroes([*c]FunctionPrototype),
    proj_count: c_int = @import("std").mem.zeroes(c_int),
};

pub const NodeTailcall = extern struct {
    super: NodeSafepoint = @import("std").mem.zeroes(NodeSafepoint),
    proto: [*c]FunctionPrototype = @import("std").mem.zeroes([*c]FunctionPrototype),
};

pub const NodeRegion = extern struct {
    tag: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    // used for IR building
    mem_in: ?*Node = @import("std").mem.zeroes(?*Node),
};

pub const LookupEntry = extern struct {
    key: i64 = @import("std").mem.zeroes(i64),
    val: u64 = @import("std").mem.zeroes(u64),
};

pub const NodeLookup = extern struct {
    entry_count: usize align(8) = @import("std").mem.zeroes(usize),
    pub fn entries(self: anytype) @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), LookupEntry) {
        const Intermediate = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        const ReturnType = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), LookupEntry);
        return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 8)));
    }
};

pub const MultiOutput = extern struct {
    count: usize = @import("std").mem.zeroes(usize),
    x: union {
        // count = 1
        single: ?*Node,
        // count > 1
        multiple: [*c]?*Node,
    } = @import("std").mem.zeroes(union {
        single: ?*Node,
        multiple: [*c]?*Node,
    }),
};
pub inline fn multiOutput(o: anytype) @TypeOf(if (o.count > @as(c_int, 1)) o.multiple else &o.single) {
    _ = &o;
    return if (o.count > @as(c_int, 1)) o.multiple else &o.single;
}

pub const SwitchEntry = extern struct {
    key: i64 = @import("std").mem.zeroes(i64),
    value: ?*Node = @import("std").mem.zeroes(?*Node),
};
pub const Safepoint = extern struct {
    node: ?*Node align(8) = @import("std").mem.zeroes(?*Node),
    userdata: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    ip: u32 = @import("std").mem.zeroes(u32),
    count: u32 = @import("std").mem.zeroes(u32),
    pub fn values(self: anytype) @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), c_int) {
        const Intermediate = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        const ReturnType = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), c_int);
        return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 24)));
    }
};

pub const ModuleSectionFlags = enum(c_int) {
    WRITE = 1,
    EXEC = 2,
    TLS = 4,
};

pub const InlineAsmRA = ?*const fn (?*Node, ?*anyopaque) callconv(.C) void;
//
// This is the function that'll emit bytes from a TB_INLINE_ASM node
pub const InlineAsmEmit = ?*const fn (?*Node, ?*anyopaque, usize, [*c]u8) callconv(.C) usize;

pub const NodeInlineAsm = extern struct {
    ctx: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    ra: InlineAsmRA = @import("std").mem.zeroes(InlineAsmRA),
    emit: InlineAsmEmit = @import("std").mem.zeroes(InlineAsmEmit),
};

// *******************************
// Public macros
// *******************************
inline fn createDataType(comptime tag: DataTypeTag, comptime x: u4) DataType {
    return DataType{
        .x = .{
            .type = tag,
            .elem_or_addrspace = x,
        },
    };
}
pub inline fn typeTuple() DataType {
    return createDataType(DataTypeTag.TUPLE, 0);
}
pub inline fn typeControl() DataType {
    return createDataType(DataTypeTag.CONTROL, 0);
}
pub inline fn typeVoid() DataType {
    return createDataType(DataTypeTag.VOID, 0);
}
pub inline fn typeBool() DataType {
    return createDataType(DataTypeTag.BOOL, 0);
}
pub inline fn typeI8() DataType {
    return createDataType(DataTypeTag.I8, 0);
}
pub inline fn typeI16() DataType {
    return createDataType(DataTypeTag.I16, 0);
}
pub inline fn typeI32() DataType {
    return createDataType(DataTypeTag.I32, 0);
}
pub inline fn typeI64() DataType {
    return createDataType(DataTypeTag.I64, 0);
}
pub inline fn typeF32() DataType {
    return createDataType(DataTypeTag.F32, 0);
}
pub inline fn typeF64() DataType {
    return createDataType(DataTypeTag.F64, 0);
}
pub inline fn createPTR() DataType {
    return createDataType(DataTypeTag.PTR, 0);
}
pub inline fn createMemory() DataType {
    return createDataType(DataTypeTag.MEMORY, 0);
}
pub inline fn createPTRN(comptime x: u4) DataType {
    return createDataType(DataTypeTag.PTR, x);
}

pub const ArenaChunk = opaque {};
pub const Arena = extern struct {
    top: ?*ArenaChunk = @import("std").mem.zeroes(?*ArenaChunk),
    tag: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    allocs: u32 = @import("std").mem.zeroes(u32),
    alloc_bytes: u32 = @import("std").mem.zeroes(u32),
};
pub const ArenaSavepoint = extern struct {
    top: ?*ArenaChunk = @import("std").mem.zeroes(?*ArenaChunk),
    avail: [*c]u8 = @import("std").mem.zeroes([*c]u8),
};

pub const arenaCreate = @extern(*const fn (noalias arena: [*c]Arena, optionalTag: [*c]const u8) callconv(.C) void, .{ .name = "tb_arena_create" });
pub const arenaDestroy = @extern(*const fn (noalias arena: [*c]Arena) callconv(.C) void, .{ .name = "tb_arena_destroy" });
pub const arenaClear = @extern(*const fn (noalias arena: [*c]Arena) callconv(.C) void, .{ .name = "tb_arena_clear" });
pub const arenaIsEmpty = @extern(*const fn (noalias arena: [*c]Arena) callconv(.C) bool, .{ .name = "tb_arena_is_empty" });
pub const arenaSave = @extern(*const fn (noalias arena: [*c]Arena) callconv(.C) ArenaSavepoint, .{ .name = "tb_arena_save" });
pub const arenaRestore = @extern(*const fn (noalias arena: [*c]Arena, sp: ArenaSavepoint) callconv(.C) void, .{ .name = "tb_arena_restore" });

////////////////////////////////
// Module management
////////////////////////////////
// Creates a module with the correct target and settings
pub const moduleCreate = @extern(*const fn (arch: Arch, sys: System, isJit: bool) callconv(.C) ?*Module, .{ .name = "tb_module_create" });

// Creates a module but defaults on the architecture and system based on the host machine
pub const moduleCreateForHost = @extern(*const fn (isJit: bool) callconv(.C) ?*Module, .{ .name = "tb_module_create_for_host" });

// Frees all resources for the TB_Module and it's functions, globals and
pub const moduleDestroy = @extern(*const fn (m: ?*Module) callconv(.C) void, .{ .name = "tb_module_destroy" });

// When targetting windows & thread local storage, you'll need to bind a tls index
// which is usually just a global that the runtime support has initialized, if you
// dont and the tls_index is used, it'll crash
pub const moduleSetTlsIndex = @extern(*const fn (m: ?*Module, len: c_long, name: [*c]const u8) callconv(.C) void, .{ .name = "tb_module_destroy" });

pub const moduleEnableChkstk = @extern(*const fn (m: ?*Module) callconv(.C) void, .{ .name = "tb_module_enable_chkstk" });

// not thread-safe
pub const moduleCreateSection = @extern(*const fn (m: ?*Module, len: c_long, name: [*c]const u8, flags: ModuleSectionFlags, combat: ComdatType) callconv(.C) ModuleSectionHandle, .{ .name = "tb_module_create_section" });

////////////////////////////////
// Compiled code introspection
////////////////////////////////
pub const TB_ASSEMBLY_CHUNK_CAP: c_int = 4080;

pub const Assembly = extern struct {
    next: [*c]Assembly align(8) = @import("std").mem.zeroes([*c]Assembly),

    // nice chunk of text here
    length: usize = @import("std").mem.zeroes(usize),
    pub fn data(self: anytype) @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8) {
        const Intermediate = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        const ReturnType = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 16)));
    }
};

// this is where the machine code and other relevant pieces go.
pub const FunctionOutput = opaque {};

pub const outputPrintAsm = @extern(*const fn (out: ?*FunctionOutput, fp: c.FILE) callconv(.C) void, .{ .name = "tb_output_print_asm" });

pub const outputGetCode = @extern(*const fn (out: ?*FunctionOutput, out_length: [*c]usize) callconv(.C) [*c]u8, .{ .name = "tb_output_get_code" });

// returns NULL if there's no line info
pub const outputGetLocation = @extern(*const fn (out: ?*FunctionOutput, out_count: [*c]usize) callconv(.C) [*c]Location, .{ .name = "tb_output_get_locations" });

// returns NULL if no assembly was generated
pub const outputGetAsm = @extern(*const fn (out: ?*FunctionOutput) callconv(.C) [*c]Assembly, .{ .name = "tb_output_get_asm" });

// this is relative to the start of the function (the start of the prologue)
pub const safepointGet = @extern(*const fn (f: ?*Function, relative_ip: u32) callconv(.C) [*c]Safepoint, .{ .name = "tb_safepoint_get" });

////////////////////////////////
// Disassembler
////////////////////////////////
pub const printDisassemblyInst = @extern(*const fn (arch: Arch, length: usize, ptr: ?*const anyopaque) callconv(.C) c_long, .{ .name = "tb_print_disassembly_inst" });

////////////////////////////////
// JIT compilation
////////////////////////////////
pub const JIT = opaque {};
pub const CPUContext = opaque {};

// passing 0 to jit_heap_capacity will default to 4MiB
pub const jitBegin = @extern(*const fn (m: ?*Module, jit_heap_capacity: usize) callconv(.C) ?*JIT, .{ .name = "tb_jit_begin" });
pub const jitPlanceFunction = @extern(*const fn (jit: ?*JIT, f: ?*Function) callconv(.C) ?*anyopaque, .{ .name = "tb_jit_place_function" });
pub const jitPlaceGlobal = @extern(*const fn (jit: ?*JIT, g: ?*Global) callconv(.C) ?*anyopaque, .{ .name = "tb_jit_place_global" });
pub const jitAllocObj = @extern(*const fn (jit: ?*JIT, size: usize, @"align": usize) callconv(.C) ?*anyopaque, .{ .name = "tb_jit_alloc_obj" });
pub const jitFreeObj = @extern(*const fn (jit: ?*JIT, ptr: ?*anyopaque) callconv(.C) void, .{ .name = "tb_jit_free_obj" });
pub const jitDumpHeap = @extern(*const fn (jit: ?*JIT) callconv(.C) void, .{ .name = "tb_jit_dump_heap" });
pub const jitEnd = @extern(*const fn (jit: ?*JIT) callconv(.C) void, .{ .name = "tb_jit_end" });

pub const TB_ResolvedAddr = extern struct {
    tag: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    offset: u32 = @import("std").mem.zeroes(u32),
};

pub const jitResolveAddr = @extern(*const fn (jit: ?*JIT, ptr: ?*anyopaque, offset: [*c]u32) callconv(.C) ?*anyopaque, .{ .name = "tb_jit_resolve_addr" });
pub const jitGetCodePtr = @extern(*const fn (f: ?*Function) callconv(.C) ?*anyopaque, .{ .name = "tb_jit_get_code_ptr" });

// you can take an tag an allocation, fresh space for random userdata :)
pub const jitTagObject = @extern(*const fn (jit: ?*JIT, ptr: ?*anyopaque, tag: ?*anyopaque) callconv(.C) void, .{ .name = "tb_jit_tag_object" });

// Debugger stuff
//   creates a new context we can run JIT code in, you don't
//   technically need this but it's a nice helper for writing
//   JITs especially when it comes to breakpoints (and eventually
//   safepoints)
pub const jitThreadCreate = @extern(*const fn (jit: ?*JIT, ud_size: usize) callconv(.C) ?*CPUContext, .{ .name = "tb_jit_thread_create" });
pub const jitThreadGetUserdata = @extern(*const fn (cpu: ?*CPUContext) callconv(.C) ?*anyopaque, .{ .name = "tb_jit_thread_get_userdata" });
pub const jitBreakpoint = @extern(*const fn (jit: ?*JIT, addr: ?*anyopaque) callconv(.C) void, .{ .name = "tb_jit_breakpoint" });

// changes the pollsite of the thread to fault such that the execution stops.
pub const jitThreadPause = @extern(*const fn (cpu: ?*CPUContext) callconv(.C) void, .{ .name = "tb_jit_thread_pause" });

// offsetof pollsite in the CPUContext
pub const jitThreadPollsite = @extern(*const fn () callconv(.C) usize, .{ .name = "tb_jit_thread_pollsite" });

// Only relevant when you're pausing the thread
pub const jitThreadPC = @extern(*const fn (cpu: ?*CPUContext) callconv(.C) ?*anyopaque, .{ .name = "tb_jit_thread_pc" });
pub const jitThreadSP = @extern(*const fn (cpu: ?*CPUContext) callconv(.C) ?*anyopaque, .{ .name = "tb_jit_thread_sp" });

pub const jitThreadCall = @extern(*const fn (cpu: ?*CPUContext, pc: ?*anyopaque, ret: [*c]u64, arg_count: usize, args: [*c]?*anyopaque) callconv(.C) bool, .{ .name = "tb_jit_thread_call" });

// returns true if we stepped off the end and returned through the trampoline
pub const jitThreadStep = @extern(*const fn (cpu: ?*CPUContext, ret: [*c]u64, pc_start: usize, pc_end: usize) callconv(.C) bool, .{ .name = "tb_jit_thread_step" });

////////////////////////////////
// Exporter
////////////////////////////////
// Export buffers are generated in chunks because it's easier, usually the
// chunks are "massive" (representing some connected piece of the buffer)
// but they don't have to be.
pub const ExportChunk = extern struct {
    next: [*c]ExportChunk align(8) = @import("std").mem.zeroes([*c]ExportChunk),
    pos: usize = @import("std").mem.zeroes(usize),
    size: usize = @import("std").mem.zeroes(usize),
    pub fn data(self: anytype) @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8) {
        const Intermediate = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        const ReturnType = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 24)));
    }
};

pub const ExportBuffer = extern struct {
    total: usize = @import("std").mem.zeroes(usize),
    head: [*c]ExportChunk = @import("std").mem.zeroes([*c]ExportChunk),
    tail: [*c]ExportChunk = @import("std").mem.zeroes([*c]ExportChunk),
};

pub const moduleObjectExport = @extern(*const fn (m: ?*Module, dst_arena: [*c]Arena, debug_fmt: DebugFormat) callconv(.C) ExportBuffer, .{ .name = "tb_module_object_export" });
pub const exportBufferToFile = @extern(*const fn (buffer: ExportBuffer, path: [*c]const u8) callconv(.C) bool, .{ .name = "tb_export_buffer_to_file" });

////////////////////////////////
// Symbols
////////////////////////////////
pub const externCreate = @extern(*const fn (m: ?*Module, len: c_long, name: [*c]const u8, @"type": ExternalType) callconv(.C) [*c]Symbol, .{ .name = "tb_extern_create" });

pub const getSourceFile = @extern(*const fn (m: ?*Module, len: c_long, path: [*c]const u8) callconv(.C) [*c]SourceFile, .{ .name = "tb_get_source_file" });

////////////////////////////////
// Function Prototypes
////////////////////////////////
pub const PrototypeParam = extern struct {
    dt: DataType = @import("std").mem.zeroes(DataType),
    debug_type: ?*DebugType = @import("std").mem.zeroes(?*DebugType),
    name: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
};

pub const FunctionPrototype = extern struct {
    call_conv: CallingConv align(8) = @import("std").mem.zeroes(CallingConv),
    return_count: u16 = @import("std").mem.zeroes(u16),
    param_count: u16 = @import("std").mem.zeroes(u16),
    has_varargs: bool = @import("std").mem.zeroes(bool),
    pub fn params(self: anytype) @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), PrototypeParam) {
        const Intermediate = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        const ReturnType = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), PrototypeParam);
        return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 16)));
    }
};
pub inline fn prototypeReturns(p: anytype) @TypeOf(p.*.params + p.*.param_count) {
    _ = &p;
    return p.*.params + p.*.param_count;
}

// creates a function prototype used to define a function's parameters and returns.
//
// function prototypes do not get freed individually and last for the entire run
// of the backend, they can also be reused for multiple functions which have
// matching signatures.
pub const prototypeCreate = @extern(*const fn (m: ?*Module, cc: CallingConv, param_count: usize, params: ?*const PrototypeParam, return_count: usize, returns: ?*const PrototypeParam, has_varargs: bool) callconv(.C) [*c]FunctionPrototype, .{ .name = "tb_prototype_create" });

// same as tb_function_set_prototype except it will handle lowering from types like the TB_DebugType
// into the correct ABI and exposing sane looking nodes to the parameters.
//
// returns the parameters
pub const functionSetPrototypeFromDBG = @extern(*const fn (f: ?*Function, section: ModuleSectionHandle, dbg: ?*DebugType, out_param_count: [*c]usize) callconv(.C) [*c]?*Node, .{ .name = "tb_function_set_prototype_from_dbg" });
pub const prototypeFromDGB = @extern(*const fn (m: ?*Module, dbg: ?*DebugType) callconv(.C) [*c]FunctionPrototype, .{ .name = "tb_prototype_from_dbg" });

// used for ABI parameter passing
pub const PassingRule = enum(c_int) {
    // needs a direct value
    DIRECT,

    // needs an address to the value
    INDIRECT,

    // doesn't use this parameter
    IGNORE,
};

pub const getPassingRuleFromDBG = @extern(*const fn (mod: ?*Module, param_type: ?*DebugType, is_return: bool) callconv(.C) PassingRule, .{ .name = "tb_get_passing_rule_from_dbg" });

////////////////////////////////
// Globals
////////////////////////////////
pub const globalCreate = @extern(*const fn (m: ?*Module, len: c_long, name: [*c]const u8, dbg_type: ?*DebugType, linkage: Linkage) callconv(.C) ?*Global, .{ .name = "tb_global_create" });

// allocate space for the global
pub const globalSetStorage = @extern(*const fn (m: ?*Module, section: ModuleSectionHandle, global: ?*Global, size: usize, @"align": usize, max_objects: usize) callconv(.C) void, .{ .name = "tb_global_set_storage" });

// returns a buffer which the user can fill to then have represented in the initializer
pub const globalAddRegion = @extern(*const fn (m: ?*Module, global: ?*Global, offset: usize, size: usize) callconv(.C) ?*anyopaque, .{ .name = "tb_global_add_region" });

pub const moduleGetText = @extern(*const fn (m: ?*Module) callconv(.C) ModuleSectionHandle, .{ .name = "tb_module_get_text" });
pub const moduleGetRData = @extern(*const fn (m: ?*Module) callconv(.C) ModuleSectionHandle, .{ .name = "tb_module_get_rdata" });
pub const moduleGetData = @extern(*const fn (m: ?*Module) callconv(.C) ModuleSectionHandle, .{ .name = "tb_module_get_data" });
pub const moduleGetTLS = @extern(*const fn (m: ?*Module) callconv(.C) ModuleSectionHandle, .{ .name = "tb_module_get_tls" });

////////////////////////////////
// Function Attributes
////////////////////////////////
// These are parts of a function that describe metadata for instructions
pub const functionAttribVariable = @extern(*const fn (f: ?*Function, n: ?*Node, parent: ?*Node, len: c_long, name: [*c]const u8, @"type": ?*DebugType) callconv(.C) void, .{ .name = "tb_function_attrib_variable" });
pub const functionAttribScope = @extern(*const fn (f: ?*Function, n: ?*Node, parent: ?*Node) callconv(.C) void, .{ .name = "tb_function_attrib_scope" });

////////////////////////////////
// Debug info Generation
////////////////////////////////
pub const debugGetVoid = @extern(*const fn (m: ?*Module) callconv(.C) ?*DebugType, .{ .name = "tb_debug_get_void" });
pub const debugGetBool = @extern(*const fn (m: ?*Module) callconv(.C) ?*DebugType, .{ .name = "tb_debug_get_bool" });
pub const debugGetInteger = @extern(*const fn (m: ?*Module, is_signed: bool, bits: c_int) callconv(.C) ?*DebugType, .{ .name = "tb_debug_get_integer" });
pub const debugGetFloat32 = @extern(*const fn (m: ?*Module) callconv(.C) ?*DebugType, .{ .name = "tb_debug_get_float32" });
pub const debugGetFloat64 = @extern(*const fn (m: ?*Module) callconv(.C) ?*DebugType, .{ .name = "tb_debug_get_float64" });
pub const debugCreatePtr = @extern(*const fn (m: ?*Module, base: ?*DebugType) callconv(.C) ?*DebugType, .{ .name = "tb_debug_create_ptr" });
pub const debugCreateArray = @extern(*const fn (m: ?*Module, base: ?*DebugType, count: usize) callconv(.C) ?*DebugType, .{ .name = "tb_debug_create_array" });
pub const debugCreateAlias = @extern(*const fn (m: ?*Module, base: ?*DebugType, len: c_long, tag: [*c]const u8) callconv(.C) ?*DebugType, .{ .name = "tb_debug_create_alias" });
pub const debugCreateStruct = @extern(*const fn (m: ?*Module, len: c_long, tag: [*c]const u8) callconv(.C) ?*DebugType, .{ .name = "tb_debug_create_struct" });
pub const debugCreateUnion = @extern(*const fn (m: ?*Module, len: c_long, tag: [*c]const u8) callconv(.C) ?*DebugType, .{ .name = "tb_debug_create_union" });
pub const debugCreateField = @extern(*const fn (m: ?*Module, @"type": ?*DebugType, len: c_long, name: [*c]const u8, offset: CharUnits) callconv(.C) ?*DebugType, .{ .name = "tb_debug_create_field" });

// returns the array you need to fill with fields
pub const debugRecordBegin = @extern(*const fn (m: ?*Module, @"type": ?*DebugType, count: usize) callconv(.C) [*c]?*DebugType, .{ .name = "tb_debug_record_begin" });
pub const debugRecordEnd = @extern(*const fn (@"type": ?*DebugType, size: CharUnits, @"align": CharUnits) callconv(.C) void, .{ .name = "tb_debug_record_end" });

pub const debugCreateFunc = @extern(*const fn (m: ?*Module, cc: CallingConv, param_count: usize, return_count: usize, has_varargs: bool) callconv(.C) ?*DebugType, .{ .name = "tb_debug_create_func" });

pub const debugFieldType = @extern(*const fn (@"type": ?*DebugType) callconv(.C) ?*DebugType, .{ .name = "tb_debug_field_type" });

pub const debugFuncReturnCount = @extern(*const fn (@"type": ?*DebugType) callconv(.C) usize, .{ .name = "tb_debug_func_return_count" });
pub const debugFuncParamCount = @extern(*const fn (@"type": ?*DebugType) callconv(.C) usize, .{ .name = "tb_debug_func_param_count" });

// you'll need to fill these if you make a function
pub const debugFuncParams = @extern(*const fn (@"type": ?*DebugType) callconv(.C) [*c]?*DebugType, .{ .name = "tb_debug_func_params" });
pub const debugFuncReturns = @extern(*const fn (@"type": ?*DebugType) callconv(.C) [*c]?*DebugType, .{ .name = "tb_debug_func_returns" });

////////////////////////////////
// Symbols
////////////////////////////////
// returns NULL if the tag doesn't match
pub const symbolAsFunction = @extern(*const fn (s: [*c]Symbol) callconv(.C) ?*Function, .{ .name = "tb_symbol_as_function" });
pub const symbolAsExternal = @extern(*const fn (s: [*c]Symbol) callconv(.C) ?*External, .{ .name = "tb_symbol_as_external" });
pub const symbolAsGlobal = @extern(*const fn (s: [*c]Symbol) callconv(.C) ?*Global, .{ .name = "tb_symbol_as_global" });

////////////////////////////////
// Function IR Generation
////////////////////////////////
pub const getDataTypeSize = @extern(*const fn (mod: ?*Module, dt: DataType, size: [*c]usize, @"align": [*c]usize) callconv(.C) void, .{ .name = "tb_get_data_type_size" });

pub const isntLocation = @extern(*const fn (f: ?*Function, file: [*c]SourceFile, line: c_int, column: c_int) callconv(.C) void, .{ .name = "tb_inst_location" });

// this is where the STOP will be
pub const instSetExitLocation = @extern(*const fn (f: ?*Function, file: [*c]SourceFile, line: c_int, column: c_int) callconv(.C) void, .{ .name = "tb_inst_set_exit_location" });

// if section is NULL, default to .text
pub const functionCreate = @extern(*const fn (m: ?*Module, len: c_long, name: [*c]const u8, linkage: Linkage) callconv(.C) ?*Function, .{ .name = "tb_function_create" });

pub const functionGetArena = @extern(*const fn (f: ?*Function, i: c_int) callconv(.C) [*c]Arena, .{ .name = "tb_function_get_arena" });

// if len is -1, it's null terminated
pub const symbolSetName = @extern(*const fn (s: [*c]Symbol, len: c_long, name: [*c]const u8) callconv(.C) void, .{ .name = "tb_symbol_set_name" });

pub const symbolBindPtr = @extern(*const fn (s: [*c]Symbol, ptr: ?*anyopaque) callconv(.C) void, .{ .name = "tb_symbol_bind_ptr" });
pub const symbolGetName = @extern(*const fn (s: [*c]Symbol) callconv(.C) [*c]const u8, .{ .name = "tb_symbol_get_name" });

// if arena is NULL, defaults to module arena which is freed on tb_free_thread_resources
pub const functionSetPrototype = @extern(*const fn (f: ?*Function, section: ModuleSectionHandle, p: [*c]FunctionPrototype) callconv(.C) void, .{ .name = "tb_function_set_prototype" });
pub const functionGetPrototype = @extern(*const fn (f: ?*Function) callconv(.C) [*c]FunctionPrototype, .{ .name = "tb_function_get_prototype" });

// if len is -1, it's null terminated
pub const instSetRegionName = @extern(*const fn (f: ?*Function, n: ?*Node, len: c_long, name: [*c]const u8) callconv(.C) void, .{ .name = "tb_inst_set_region_name" });

pub const instPoison = @extern(*const fn (f: ?*Function, dt: DataType) callconv(.C) ?*Node, .{ .name = "tb_inst_poison" });

pub const instRootNode = @extern(*const fn (f: ?*Function) callconv(.C) ?*Node, .{ .name = "tb_inst_root_node" });
pub const instParam = @extern(*const fn (f: ?*Function, param_id: c_int) callconv(.C) ?*Node, .{ .name = "tb_inst_param" });

pub const instFpxt = @extern(*const fn (f: ?*Function, src: ?*Node, dt: DataType) callconv(.C) ?*Node, .{ .name = "tb_inst_fpxt" });
pub const instSxt = @extern(*const fn (f: ?*Function, src: ?*Node, dt: DataType) callconv(.C) ?*Node, .{ .name = "tb_inst_sxt" });
pub const instZxt = @extern(*const fn (f: ?*Function, src: ?*Node, dt: DataType) callconv(.C) ?*Node, .{ .name = "tb_inst_zxt" });
pub const instTrunc = @extern(*const fn (f: ?*Function, src: ?*Node, dt: DataType) callconv(.C) ?*Node, .{ .name = "tb_inst_trunc" });
pub const instInt2Ptr = @extern(*const fn (f: ?*Function, src: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_int2ptr" });
pub const instPtr2Int = @extern(*const fn (f: ?*Function, src: ?*Node, dt: DataType) callconv(.C) ?*Node, .{ .name = "tb_inst_ptr2int" });
pub const instInt2Float = @extern(*const fn (f: ?*Function, src: ?*Node, dt: DataType, is_signed: bool) callconv(.C) ?*Node, .{ .name = "tb_inst_int2float" });
pub const instFloat2Int = @extern(*const fn (f: ?*Function, src: ?*Node, dt: DataType, is_signed: bool) callconv(.C) ?*Node, .{ .name = "tb_inst_float2int" });
pub const instBitcast = @extern(*const fn (f: ?*Function, src: ?*Node, dt: DataType) callconv(.C) ?*Node, .{ .name = "tb_inst_bitcast" });

pub const instLocal = @extern(*const fn (f: ?*Function, size: CharUnits, @"align": CharUnits) callconv(.C) ?*Node, .{ .name = "tb_inst_local" });

pub const instLoad = @extern(*const fn (f: ?*Function, dt: DataType, addr: ?*Node, @"align": CharUnits, is_volatile: bool) callconv(.C) ?*Node, .{ .name = "tb_inst_load" });
pub const instStore = @extern(*const fn (f: ?*Function, dt: DataType, addr: ?*Node, val: ?*Node, @"align": CharUnits, is_volatile: bool) callconv(.C) void, .{ .name = "tb_inst_store" });

pub const instBool = @extern(*const fn (f: ?*Function, imm: bool) callconv(.C) ?*Node, .{ .name = "tb_inst_bool" });
pub const instSint = @extern(*const fn (f: ?*Function, dt: DataType, imm: i64) callconv(.C) ?*Node, .{ .name = "tb_inst_sint" });
pub const instUint = @extern(*const fn (f: ?*Function, dt: DataType, imm: u64) callconv(.C) ?*Node, .{ .name = "tb_inst_uint" });
pub const instFloat32 = @extern(*const fn (f: ?*Function, imm: f32) callconv(.C) ?*Node, .{ .name = "tb_inst_float32" });
pub const instFloat64 = @extern(*const fn (f: ?*Function, imm: f64) callconv(.C) ?*Node, .{ .name = "tb_inst_float64" });
pub const instCstring = @extern(*const fn (f: ?*Function, str: [*c]const u8) callconv(.C) ?*Node, .{ .name = "tb_inst_cstring" });
pub const instString = @extern(*const fn (f: ?*Function, len: usize, str: [*c]const u8) callconv(.C) ?*Node, .{ .name = "tb_inst_string" });

// write 'val' over 'count' bytes on 'dst'
pub const instMemset = @extern(*const fn (f: ?*Function, dst: ?*Node, val: ?*Node, count: ?*Node, @"align": CharUnits) callconv(.C) void, .{ .name = "tb_inst_memset" });

// zero 'count' bytes on 'dst'
pub const instMemzero = @extern(*const fn (f: ?*Function, dst: ?*Node, count: ?*Node, @"align": CharUnits) callconv(.C) void, .{ .name = "tb_inst_memzero" });

// performs a copy of 'count' elements from one memory location to another
// both locations cannot overlap.
pub const instMemcpy = @extern(*const fn (f: ?*Function, dst: ?*Node, src: ?*Node, count: ?*Node, @"align": CharUnits) callconv(.C) void, .{ .name = "tb_inst_memcpy" });

// result = base + (index * stride)
pub const instArrayAccess = @extern(*const fn (f: ?*Function, base: ?*Node, index: ?*Node, stride: i64) callconv(.C) ?*Node, .{ .name = "tb_inst_array_access" });

// result = base + offset
// where base is a pointer
pub const instMemberAccess = @extern(*const fn (f: ?*Function, base: ?*Node, offset: i64) callconv(.C) ?*Node, .{ .name = "tb_inst_member_access" });

pub const instGetSymbolAddress = @extern(*const fn (f: ?*Function, target: [*c]Symbol) callconv(.C) ?*Node, .{ .name = "tb_inst_get_symbol_address" });

// Performs a conditional select between two values, if the operation is
// performed wide then the cond is expected to be the same type as a and b where
// the condition is resolved as true if the MSB (per component) is 1.
//
// result = cond ? a : b
// a, b must match in type
pub const instSelect = @extern(*const fn (f: ?*Function, cond: ?*Node, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_select" });

// Integer arithmatic
pub const instAdd = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node, arith_behavior: ArithmeticBehavior) callconv(.C) ?*Node, .{ .name = "tb_inst_add" });
pub const instSub = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node, arith_behavior: ArithmeticBehavior) callconv(.C) ?*Node, .{ .name = "tb_inst_sub" });
pub const instMul = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node, arith_behavior: ArithmeticBehavior) callconv(.C) ?*Node, .{ .name = "tb_inst_mul" });
pub const instDiv = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node, signedness: bool) callconv(.C) ?*Node, .{ .name = "tb_inst_div" });
pub const instMod = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node, signedness: bool) callconv(.C) ?*Node, .{ .name = "tb_inst_mod" });

// Bitmagic operations
pub const instBswap = @extern(*const fn (f: ?*Function, n: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_bswap" });
pub const instClz = @extern(*const fn (f: ?*Function, n: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_clz" });
pub const instCtz = @extern(*const fn (f: ?*Function, n: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_ctz" });
pub const instPopcount = @extern(*const fn (f: ?*Function, n: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_popcount" });

// Bitwise operations
pub const instNot = @extern(*const fn (f: ?*Function, n: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_not" });
pub const instNeg = @extern(*const fn (f: ?*Function, n: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_neg" });
pub const instAnd = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_and" });
pub const instOr = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_or" });
pub const instXor = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_xor" });
pub const instSar = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_sar" });
pub const instShl = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node, arith_behavior: ArithmeticBehavior) callconv(.C) ?*Node, .{ .name = "tb_inst_shl" });
pub const instShr = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_shr" });
pub const instRol = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_rol" });
pub const isntRor = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_ror" });

// Atomics
// By default you can use TB_MEM_ORDER_SEQ_CST for the memory order to get
// correct but possibly slower results on certain platforms (those with relaxed
// memory models).

// Must be aligned to the natural alignment of dt
pub const instAtomicLoad = @extern(*const fn (f: ?*Function, addr: ?*Node, dt: DataType, order: MemoryOrder) callconv(.C) ?*Node, .{ .name = "tb_inst_atomic_load" });

// All atomic operations here return the old value and the operations are
// performed in the same data type as 'src' with alignment of 'addr' being
// the natural alignment of 'src'
pub const instAtomicXchg = @extern(*const fn (f: ?*Function, addr: ?*Node, src: ?*Node, order: MemoryOrder) callconv(.C) ?*Node, .{ .name = "tb_inst_atomic_xchg" });
pub const instAtomicAdd = @extern(*const fn (f: ?*Function, addr: ?*Node, src: ?*Node, order: MemoryOrder) callconv(.C) ?*Node, .{ .name = "tb_inst_atomic_add" });
pub const instAtomicAnd = @extern(*const fn (f: ?*Function, addr: ?*Node, src: ?*Node, order: MemoryOrder) callconv(.C) ?*Node, .{ .name = "tb_inst_atomic_and" });
pub const instAtomicXor = @extern(*const fn (f: ?*Function, addr: ?*Node, src: ?*Node, order: MemoryOrder) callconv(.C) ?*Node, .{ .name = "tb_inst_atomic_xor" });
pub const instAtomicOr = @extern(*const fn (f: ?*Function, addr: ?*Node, src: ?*Node, order: MemoryOrder) callconv(.C) ?*Node, .{ .name = "tb_inst_atomic_or" });

// returns old_value from *addr
pub const instAtomicCmpxchg = @extern(*const fn (f: ?*Function, addr: ?*Node, expected: ?*Node, desired: ?*Node, succ: MemoryOrder, fail: MemoryOrder) callconv(.C) ?*Node, .{ .name = "tb_inst_atomic_cmpxchg" });

// Float math
pub const instFadd = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_fadd" });
pub const instFsub = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_fsub" });
pub const isntFmul = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_fmul" });
pub const instFdiv = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_fdiv" });

// Comparisons
pub const instCmpEq = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_cmp_eq" });
pub const instCmpNe = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_cmp_ne" });

pub const instCmpIlt = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node, signedness: bool) callconv(.C) ?*Node, .{ .name = "tb_inst_cmp_ilt" });

pub const instCmpIle = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node, signedness: bool) callconv(.C) ?*Node, .{ .name = "tb_inst_cmp_ile" });

pub const instCmpIgt = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node, signedness: bool) callconv(.C) ?*Node, .{ .name = "tb_inst_cmp_igt" });

pub const instCmpIge = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node, signedness: bool) callconv(.C) ?*Node, .{ .name = "tb_inst_cmp_ige" });

pub const instCmpFlt = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_cmp_flt" });
pub const instCmpFle = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_cmp_fle" });
pub const instCmpFgt = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_cmp_fgt" });
pub const instCmpFge = @extern(*const fn (f: ?*Function, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_cmp_fge" });

// General intrinsics
pub const instVaStart = @extern(*const fn (f: ?*Function, a: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_va_start" });
pub const instCycleCounter = @extern(*const fn (f: ?*Function) callconv(.C) ?*Node, .{ .name = "tb_inst_cycle_counter" });
pub const instPrefetch = @extern(*const fn (f: ?*Function, addr: ?*Node, level: c_int) callconv(.C) ?*Node, .{ .name = "tb_inst_prefetch" });

// x86 Intrinsics
pub const instX86Ldmxcsr = @extern(*const fn (f: ?*Function, a: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_x86_ldmxcsr" });
pub const instX86Stmxcsr = @extern(*const fn (f: ?*Function) callconv(.C) ?*Node, .{ .name = "tb_inst_x86_stmxcsr" });
pub const instX86Sqrt = @extern(*const fn (f: ?*Function, a: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_x86_sqrt" });
pub const instX86Rsqrt = @extern(*const fn (f: ?Function, a: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_x86_rsqrt" });

// Control flow
//   trace is a single-entry piece of IR.
pub const Trace = extern struct {
    top_ctrl: ?*Node = @import("std").mem.zeroes(?*Node),
    bot_ctrl: ?*Node = @import("std").mem.zeroes(?*Node),

    // latest memory effect, for now there's
    // only one stream going at a time but that'll
    // have to change for some of the interesting
    // langs later.
    mem: ?*Node = @import("std").mem.zeroes(?*Node),
};

// Old-style uses regions for all control flow similar to how people use basic blocks
pub const instRegion = @extern(*const fn (f: ?*Function) callconv(.C) ?*Node, .{ .name = "tb_inst_region" });
pub const instSetControl = @extern(*const fn (f: ?*Function, region: ?*Node) callconv(.C) void, .{ .name = "tb_inst_set_control" });
pub const instGetControl = @extern(*const fn (f: ?*Function) callconv(.C) ?*Node, .{ .name = "tb_inst_get_control" });

// But since regions aren't basic blocks (they only guarentee single entry, not single exit)
// the new-style is built for that.
pub const instNewTrace = @extern(*const fn (f: ?*Function) callconv(.C) Trace, .{ .name = "tb_inst_new_trace" });
pub const instGetTrace = @extern(*const fn (f: ?*Function) callconv(.C) Trace, .{ .name = "tb_inst_get_trace" });

// only works on regions which haven't been constructed yet
pub const instTraceFromRegion = @extern(*const fn (f: ?*Function, region: ?*Node) callconv(.C) Trace, .{ .name = "tb_inst_trace_from_region" });
pub const instRegionMenIn = @extern(*const fn (f: ?*Function, region: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_region_mem_in" });

pub const instSyscall = @extern(*const fn (f: ?*Function, dt: DataType, syscall_num: ?*Node, param_count: usize, params: [*c]?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_syscall" });
pub const instCall = @extern(*const fn (f: ?*Function, proto: [*c]FunctionPrototype, target: ?*Node, param_count: usize, params: [*c]?*Node) callconv(.C) MultiOutput, .{ .name = "tb_inst_call" });
pub const instTailCall = @extern(*const fn (f: ?*Function, proto: [*c]FunctionPrototype, target: ?*Node, param_count: usize, params: [*c]?*Node) callconv(.C) void, .{ .name = "tb_inst_tailcall" });

pub const instSafePoint = @extern(*const fn (f: ?*Function, poke_site: ?*Node, param_count: usize, params: [*c]?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_safepoint" });

pub const instIncompletePhi = @extern(*const fn (f: ?*Function, dt: DataType, region: ?*Node, preds: usize) callconv(.C) ?*Node, .{ .name = "tb_inst_incomplete_phi" });
pub const adddPhiOperand = @extern(*const fn (f: ?*Function, phi: ?*Node, region: ?*Node, val: ?*Node) callconv(.C) bool, .{ .name = "tb_inst_add_phi_operand" });

pub const instPhi2 = @extern(*const fn (f: ?*Function, region: ?*Node, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_phi2" });
pub const instIf = @extern(*const fn (f: ?*Function, cond: ?*Node, true_case: ?*Node, false_case: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_if" });
pub const instBranch = @extern(*const fn (f: ?*Function, dt: DataType, key: ?*Node, default_case: ?*Node, entry_count: usize, keys: [*c]const SwitchEntry) callconv(.C) ?*Node, .{ .name = "tb_inst_branch" });
pub const instUnreachable = @extern(*const fn (f: ?*Function) callconv(.C) void, .{ .name = "tb_inst_unreachable" });
pub const instDebugBreak = @extern(*const fn (f: ?*Function) callconv(.C) void, .{ .name = "tb_inst_debugbreak" });
pub const instTrap = @extern(*const fn (f: ?*Function) callconv(.C) void, .{ .name = "tb_inst_trap" });
pub const instGoto = @extern(*const fn (f: ?*Function, target: ?*Node) callconv(.C) void, .{ .name = "tb_inst_goto" });
pub const instNeverBranch = @extern(*const fn (f: ?*Function, if_true: ?*Node, if_false: ?*Node) callconv(.C) void, .{ .name = "tb_inst_never_branch" });

pub const nodeGetName = @extern(*const fn (n_type: NodeTypeEnum) callconv(.C) [*c]const u8, .{ .name = "tb_node_get_name" });

// revised API for if, this one returns the control projections such that a target is not necessary while building
//   projs[0] is the true case, projs[1] is false.
pub const instIf2 = @extern(*const fn (f: ?*Function, cond: ?*Node, projs: [*c]?*Node) callconv(.C) ?*Node, .{ .name = "tb_inst_if2" });

// n is a TB_BRANCH with two successors, taken is the number of times it's true
pub const instSetBranchFreq = @extern(*const fn (f: ?*Function, n: ?*Node, total_hits: c_int, taken: c_int) callconv(.C) void, .{ .name = "tb_inst_set_branch_freq" });

pub const instRet = @extern(*const fn (f: ?*Function, count: usize, values: [*c]?*Node) callconv(.C) void, .{ .name = "tb_inst_ret" });

////////////////////////////////
// optimizer api
////////////////////////////////
// to avoid allocs, you can make a worklist and keep it across multiple functions so long
// as they're not trying to use it at the same time.
pub const Worklist = opaque {};

pub const worklistAlloc = @extern(*const fn () callconv(.C) ?*Worklist, .{ .name = "tb_worklist_alloc" });
pub const worklistFree = @extern(*const fn (ws: ?*Worklist) callconv(.C) void, .{ .name = "tb_worklist_free" });

// if you decide during tb_opt that you wanna preserve the types, this is how you'd later free them.
pub const optFreeTypes = @extern(*const fn (f: ?*Function) callconv(.C) void, .{ .name = "tb_opt_free_types" });

// this will allocate the worklist, you can free worklist once you're done with analysis/transforms.
pub const optPushAllNodes = @extern(*const fn (f: ?*Function) callconv(.C) void, .{ .name = "tb_opt_push_all_nodes" });
pub const optDumpStats = @extern(*const fn (f: ?*Function) callconv(.C) void, .{ .name = "tb_opt_dump_stats" });

// returns GVN on a new node, returning either the same node or a duplicate node 'k'.
// it deletes 'n' if it's a duplicate btw.
pub const optGvnNode = @extern(*const fn (f: ?*Function, n: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_opt_gvn_node" });
// returns isomorphic node that's run it's peepholes.
pub const optPeepNode = @extern(*const fn (f: ?*Function, n: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_opt_peep_node" });

// Uses the two function arenas pretty heavily, may even flip their purposes (as a form
// of GC compacting)
//
// returns true if any graph rewrites were performed.
pub const opt = @extern(*const fn (f: ?*Function, ws: ?*Worklist, preserve_types: bool) callconv(.C) bool, .{ .name = "tb_opt" });
//
// print in SSA-CFG looking form (with BB params for the phis), if tmp is NULL it'll use the
// function's tmp arena
pub const print = @extern(*const fn (f: ?*Function) callconv(.C) void, .{ .name = "tb_print" });
pub const printDump = @extern(*const fn (f: ?*Function) callconv(.C) void, .{ .name = "tb_print_dumb" });
pub const printSvg = @extern(*const fn (f: ?*Function) callconv(.C) void, .{ .name = "tb_print_svg" });

// codegen:
//   output goes at the top of the code_arena, feel free to place multiple functions
//   into the same code arena (although arenas aren't thread-safe you'll want one per thread
//   at least)
//
//   if code_arena is NULL, the IR arena will be used.
pub const codegen = @extern(*const fn (f: ?*Function, ws: ?*Worklist, code_arena: [*c]Arena, features: [*c]const FeatureSet, emit_asm: bool) callconv(.C) ?*FunctionOutput, .{ .name = "tb_codegen" });

// interprocedural optimizer iter
pub const moduleIpo = @extern(*const fn (m: ?*Module) callconv(.C) bool, .{ .name = "tb_module_ipo" });

////////////////////////////////
// Cooler IR building
////////////////////////////////
pub const GraphBuilder = opaque {};
pub const GRAPH_BUILDER_PARAMS: c_int = 0;

// if ws != NULL, i'll run the peepholes while you're constructing nodes. why? because it
// avoids making junk nodes before they become a problem for memory bandwidth.
pub const builderEnter = @extern(*const fn (f: ?*Function, section: ModuleSectionHandle, proto: [*c]FunctionPrototype, ws: ?*Worklist) callconv(.C) ?*GraphBuilder, .{ .name = "tb_builder_enter" });

// parameter's addresses are available through the tb_builder_param_addr, they're not tracked as mutable vars.
pub const builderEnterFromDbg = @extern(*const fn (f: ?*Function, section: ModuleSectionHandle, dbg: ?*DebugType, ws: ?*Worklist) callconv(.C) ?*GraphBuilder, .{ .name = "tb_builder_enter_from_dbg" });
pub const builderExit = @extern(*const fn (g: ?*GraphBuilder) callconv(.C) void, .{ .name = "tb_builder_exit" });
pub const builderParamAddr = @extern(*const fn (g: ?*GraphBuilder, i: c_int) callconv(.C) ?*Node, .{ .name = "tb_builder_param_addr" });
pub const builderBool = @extern(*const fn (g: ?*GraphBuilder, x: bool) callconv(.C) ?*Node, .{ .name = "tb_builder_bool" });
pub const builderUint = @extern(*const fn (g: ?*GraphBuilder, dt: DataType, x: u64) callconv(.C) ?*Node, .{ .name = "tb_builder_uint" });
pub const builderSint = @extern(*const fn (g: ?*GraphBuilder, dt: DataType, x: i64) callconv(.C) ?*Node, .{ .name = "tb_builder_sint" });
pub const builderFloat32 = @extern(*const fn (g: ?*GraphBuilder, imm: f32) callconv(.C) ?*Node, .{ .name = "tb_builder_float32" });
pub const builderFloat64 = @extern(*const fn (g: ?*GraphBuilder, imm: f64) callconv(.C) ?*Node, .{ .name = "tb_builder_float64" });
pub const builderSymbol = @extern(*const fn (g: ?*GraphBuilder, sym: [*c]Symbol) callconv(.C) ?*Node, .{ .name = "tb_builder_symbol" });
pub const builderString = @extern(*const fn (g: ?*GraphBuilder, len: c_long, str: [*c]const u8) callconv(.C) ?*Node, .{ .name = "tb_builder_string" });

// works with type: AND, OR, XOR, ADD, SUB, MUL, SHL, SHR, SAR, ROL, ROR, UDIV, SDIV, UMOD, SMOD.
// note that arithmetic behavior is irrelevant for some of the operations (but 0 is always a good default).
pub const builderBinopInt = @extern(*const fn (g: ?*GraphBuilder, @"type": c_int, a: ?*Node, b: ?*Node, ab: ArithmeticBehavior) callconv(.C) ?*Node, .{ .name = "tb_builder_binop_int" });
pub const builderBinopFloat = @extern(*const fn (g: ?*GraphBuilder, @"type": c_int, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_builder_binop_float" });

pub const builderSelect = @extern(*const fn (g: ?*GraphBuilder, cond: ?*Node, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_builder_select" });
pub const builderCast = @extern(*const fn (g: ?*GraphBuilder, dt: DataType, @"type": c_int, src: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_builder_cast" });

// ( a -- b )
pub const builderUnary = @extern(*const fn (g: ?*GraphBuilder, @"type": c_int, src: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_builder_unary" });

pub const builderNeg = @extern(*const fn (g: ?*GraphBuilder, src: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_builder_neg" });
pub const builderNot = @extern(*const fn (g: ?*GraphBuilder, src: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_builder_not" });

// ( a b -- c )
pub const builderCmp = @extern(*const fn (g: ?*GraphBuilder, @"type": c_int, a: ?*Node, b: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_builder_cmp" });

// pointer arithmetic
//   base + index*stride
pub const builderPtrArray = @extern(*const fn (g: ?*GraphBuilder, base: ?*Node, index: ?*Node, stride: i64) callconv(.C) ?*Node, .{ .name = "tb_builder_ptr_array" });
//   base + offset
pub const builderPtrNumber = @extern(*const fn (g: ?*GraphBuilder, base: ?*Node, offset: i64) callconv(.C) ?*Node, .{ .name = "tb_builder_ptr_member" });

// memory
pub const builderLoad = @extern(*const fn (g: ?*GraphBuilder, mem_var: c_int, ctrl_dep: bool, dt: DataType, addr: ?*Node, @"align": CharUnits, is_volatile: bool) callconv(.C) ?*Node, .{ .name = "tb_builder_load" });
pub const builderStore = @extern(*const fn (g: ?*GraphBuilder, mem_var: c_int, ctrl_dep: bool, addr: ?*Node, val: ?*Node, @"align": CharUnits, is_volatile: bool) callconv(.C) void, .{ .name = "tb_builder_store" });
pub const builderMemcpy = @extern(*const fn (g: ?*GraphBuilder, mem_var: c_int, ctrl_dep: bool, dst: ?*Node, src: ?*Node, size: ?*Node, @"align": CharUnits, is_volatile: bool) callconv(.C) void, .{ .name = "tb_builder_memcpy" });
pub const builderMemset = @extern(*const fn (g: ?*GraphBuilder, mem_var: c_int, ctrl_dep: bool, dst: ?*Node, val: ?*Node, size: ?*Node, @"align": CharUnits, is_volatile: bool) callconv(.C) void, .{ .name = "tb_builder_memset" });
pub const builderMemzero = @extern(*const fn (g: ?*GraphBuilder, mem_var: c_int, ctrl_dep: bool, dst: ?*Node, size: ?*Node, @"align": CharUnits, is_volatile: bool) callconv(.C) void, .{ .name = "tb_builder_memzero" });
//
// returns initially loaded value
pub const builderAtomicRmw = @extern(*const fn (g: ?*GraphBuilder, mem_var: c_int, op: c_int, addr: ?*Node, val: ?*Node, order: MemoryOrder) callconv(.C) ?*Node, .{ .name = "tb_builder_atomic_rmw" });
pub const builderAtomicLoad = @extern(*const fn (g: ?*GraphBuilder, mem_var: c_int, dt: DataType, addr: ?*Node, order: MemoryOrder) callconv(.C) ?*Node, .{ .name = "tb_builder_atomic_load" });

// splitting/merging:
//   splits the 'in_mem' variable, this writes over in_mem with a split
//   and 'split_count' number of extra paths at 'variable[returned value]'
pub const builderSplitMem = @extern(*const fn (g: ?*GraphBuilder, in_mem: c_int, split_count: c_int, out_split: [*c]?*Node) callconv(.C) c_int, .{ .name = "tb_builder_split_mem" });
//   this will merge the memory effects back into out_mem, split_vars being the result of a tb_builder_split_mem(...)
pub const builderMergeMem = @extern(*const fn (g: ?*GraphBuilder, out_mem: c_int, split_count: c_int, split_vars: c_int, split: ?*Node) callconv(.C) void, .{ .name = "tb_builder_merge_mem" });

pub const builderLoc = @extern(*const fn (g: ?*GraphBuilder, mem_var: c_int, file: [*c]SourceFile, line: c_int, column: c_int) callconv(.C) void, .{ .name = "tb_builder_loc" });

// function call
pub const builderCall = @extern(*const fn (g: ?*GraphBuilder, proto: [*c]FunctionPrototype, mem_var: c_int, target: ?*Node, arg_count: c_int, args: [*c]?*Node) callconv(.C) [*c]?*Node, .{ .name = "tb_builder_call" });
pub const builderSyscall = @extern(*const fn (g: ?*GraphBuilder, dt: DataType, mem_var: c_int, target: ?*Node, arg_count: c_int, args: [*c]?*Node) callconv(.C) ?*Node, .{ .name = "tb_builder_syscall" });
pub const builderSafepoint = @extern(*const fn (g: ?*GraphBuilder, mem_var: c_int, userdata: ?*anyopaque, poll_site: ?*Node, arg_count: c_int, args: [*c]?*Node) callconv(.C) void, .{ .name = "tb_builder_safepoint" });

// locals (variables but as stack vars)
pub const builderLocal = @extern(*const fn (g: ?*GraphBuilder, size: CharUnits, @"align": CharUnits) callconv(.C) ?*Node, .{ .name = "tb_builder_local" });
pub const builderLocalDbg = @extern(*const fn (g: ?*GraphBuilder, n: ?*Node, len: c_long, name: [*c]const u8, @"type": ?*DebugType) callconv(.C) void, .{ .name = "tb_builder_local_dbg" });

pub const builderFramePtr = @extern(*const fn (g: ?*GraphBuilder) callconv(.C) ?*Node, .{ .name = "tb_builder_frame_ptr" });
pub const builderJitThreadPtr = @extern(*const fn (g: ?*GraphBuilder) callconv(.C) ?*Node, .{ .name = "tb_builder_jit_thread_ptr" });

// variables:
//   just gives you the ability to construct mutable names, from
//   there we just slot in the phis and such for you :)
pub const builderDecl = @extern(*const fn (g: ?*GraphBuilder, label: ?*Node) callconv(.C) c_int, .{ .name = "tb_builder_decl" });
pub const builderGetVar = @extern(*const fn (g: ?*GraphBuilder, id: c_int) callconv(.C) ?*Node, .{ .name = "tb_builder_get_var" });
pub const builderSetVar = @extern(*const fn (g: ?*GraphBuilder, id: c_int, v: ?*Node) callconv(.C) void, .{ .name = "tb_builder_set_var" });

// control flow primitives:
//   makes a region we can jump to (generally for forward jumps)
pub const builderLabelMake = @extern(*const fn (g: ?*GraphBuilder) callconv(.C) ?*Node, .{ .name = "tb_builder_label_make" });
pub const builderLabelMake2 = @extern(*const fn (g: ?*GraphBuilder, label: ?*Node, has_backward_jumps: bool) callconv(.C) ?*Node, .{ .name = "tb_builder_label_make2" });
//   once a label is complete you can no longer insert jumps to it, the phis
//   are placed and you can then insert code into the label's body.
pub const builderLabelComplete = @extern(*const fn (g: ?*GraphBuilder, label: ?*Node) callconv(.C) void, .{ .name = "tb_builder_label_complete" });
//   begin building on the label (has to be completed now), returns old label
pub const builderLabelSet = @extern(*const fn (g: ?*GraphBuilder, label: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_builder_label_set" });
//   just makes a label from an existing label (used when making the loop body defs)
pub const builderLabelClone = @extern(*const fn (g: ?*GraphBuilder, label: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_builder_label_clone" });
//   active label
pub const builderLabelGet = @extern(*const fn (g: ?*GraphBuilder) callconv(.C) ?*Node, .{ .name = "tb_builder_label_get" });
//   number of predecessors at that point in time
pub const builderLabelPredCount = @extern(*const fn (g: ?*GraphBuilder, label: ?*Node) callconv(.C) c_int, .{ .name = "tb_builder_label_pred_count" });
//   kill node
pub const builderLabelKill = @extern(*const fn (g: ?*GraphBuilder, label: ?*Node) callconv(.C) void, .{ .name = "tb_builder_label_kill" });
//   writes to the paths array the symbol tables for the branch.
//   [0] is the true case and [1] is the false case.
pub const builderIf = @extern(*const fn (g: ?*GraphBuilder, cond: ?*Node, paths: [*c]?*Node) callconv(.C) void, .{ .name = "tb_builder_if" });
//   begins empty switch statement, we can add cases as we go.
//   returns the symbol table we use to instatiate the cases.
pub const builderSwitch = @extern(*const fn (g: ?*GraphBuilder, cond: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_builder_switch" });
//   returns the symbol table for the newly created case.
pub const builderDefCase = @extern(*const fn (g: ?*GraphBuilder, br_syms: ?*Node, prob: c_int) callconv(.C) ?*Node, .{ .name = "tb_builder_def_case" });
//   returns the symbol table for the newly created case.
pub const builderKeyCase = @extern(*const fn (g: ?*GraphBuilder, br_syms: ?*Node, key: u64, prob: c_int) callconv(.C) ?*Node, .{ .name = "tb_builder_key_case" });
//   unconditional jump to target
pub const builderBr = @extern(*const fn (g: ?*GraphBuilder, target: ?*Node) callconv(.C) void, .{ .name = "tb_builder_br" });
//   forward and backward branch target
pub const builderLoop = @extern(*const fn (g: ?*GraphBuilder) callconv(.C) ?*Node, .{ .name = "tb_builder_loop" });
//   explicit phi construction
pub const builderPhi = @extern(*const fn (g: ?*GraphBuilder, val_count: c_int, vals: [*c]?*Node) callconv(.C) ?*Node, .{ .name = "tb_builder_phi" });
// technically TB has multiple returns, in practice it's like 2 regs before
// ABI runs out of shit.
pub const builderRet = @extern(*const fn (g: ?*GraphBuilder, mem_var: c_int, arg_count: c_int, args: [*c]?*Node) callconv(.C) void, .{ .name = "tb_builder_ret" });
pub const builderUnreachable = @extern(*const fn (g: ?*GraphBuilder, mem_var: c_int) callconv(.C) void, .{ .name = "tb_builder_unreachable" });
pub const builderTrap = @extern(*const fn (g: ?*GraphBuilder, mem_var: c_int) callconv(.C) void, .{ .name = "tb_builder_trap" });
pub const builderDebugBreak = @extern(*const fn (g: ?*GraphBuilder, mem_var: c_int) callconv(.C) void, .{ .name = "tb_builder_debugbreak" });

// allows you to define multiple entry points
pub const builderEntryFork = @extern(*const fn (g: ?*GraphBuilder, count: c_int, paths: [*c]?*Node) callconv(.C) void, .{ .name = "tb_builder_entry_fork" });

// general intrinsics
pub const builderCycleCounter = @extern(*const fn (g: ?*GraphBuilder) callconv(.C) ?*Node, .{ .name = "tb_builder_cycle_counter" });
pub const builderPrefetch = @extern(*const fn (g: ?*GraphBuilder, addr: ?*Node, level: c_int) callconv(.C) ?*Node, .{ .name = "tb_builder_prefetch" });

// x86 Intrinsics
pub const builderX86Ldmxcsr = @extern(*const fn (g: ?*GraphBuilder, a: ?*Node) callconv(.C) ?*Node, .{ .name = "tb_builder_x86_ldmxcsr" });
pub const builderX86Stmxcsr = @extern(*const fn (g: ?*GraphBuilder) callconv(.C) ?*Node, .{ .name = "tb_builder_x86_stmxcsr" });

////////////////////////////////
// IR access
////////////////////////////////
pub const nodeIsConstantNonZero = @extern(*const fn (n: ?*Node) callconv(.C) bool, .{ .name = "tb_node_is_constant_non_zero" });
pub const nodeIsConstantZero = @extern(*const fn (n: ?*Node) callconv(.C) bool, .{ .name = "tb_node_is_constant_zero" });
pub const a = @extern(*const fn (m: ?*Module, cc: CallingConv, has_varargs: bool) callconv(.C) [*c]FunctionPrototype, .{ .name = "a" });
