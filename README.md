# PePe

Compiler to nasm linux x86-64

## Execute Project

### Build Project

```console
zig build
```

Ouput executable will be in ./zig-out/bin/PePe

### Build and Run Project

```console
zig build run
```

Ouput executable will be in ./zig-out/bin/PePe

## Usage - Subcommands

### Build

```console
PePe build <src>
```

### Build and Run

```console
PePe run <src> <...args> -- <...executable args>
```

### Simulation

Interpreter of the same language, the output should be the same

```console
PePe sim <src> <...args> -- <...executable args>
```

## Arguments

### Bench

-b will tell you how long each thing takes

### Silence

-s with make that the output will be only errors

Silence will force bench to not work because output will be close except for errors
