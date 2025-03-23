# Yots

Compiler to fasm linux x86-64

## TODO App

A TODO (todo) app is in this repository which was built from [tsoding](https://github.com/tsoding/todo-rs)

### Controls

|Keys|Description|
|---|---|
|<kbd>k</kbd>, <kbd>j</kbd>|Move cursor up and down|
|<kbd>Shift+K</kbd>, <kbd>Shift+J</kbd>|Drag the current item up and down|
|<kbd>g</kbd>, <kbd>G</kbd> | Jump to the start, end of the current item list|
|<kbd>r</kbd>|Rename the current item|
|<kbd>i</kbd>|Insert a new item|
|<kbd>d</kbd>|Delete the current list item|
|<kbd>q</kbd>|Quit|
|<kbd>TAB</kbd>|Switch between the TODO and DONE panels|
|<kbd>Enter</kbd>|Perform an action on the highlighted UI element|

## Execute Project

### Build Project

```console
zig build
```

Ouput executable will be in ./zig-out/bin/yot

### Build and Run Project

```console
zig build run
```

Ouput executable will be in ./zig-out/bin/yot

## Usage - Subcommands

### Build

```console
yot build <src>
```

### Build and Run

```console
yot run <src> <...args> -- <...executable args>
```

### Simulation

Interpreter of the same language, the output should be the same

```console
yot sim <src> <...args> -- <...executable args>
```

### Lex

Output file with tokens

```console
yot lex <src> <...args> -- <...executable args>
```

### Parse

Output file with the statements

```console
yot parse <src> <...args> -- <...executable args>
```

### IR

Output file with the intermediate represetation

```console
yot ir <src> <...args> -- <...executable args>
```

## Arguments

### Change Output to stdout

-stdout will change the output to stdout instead  of a file

### Bench

-b will tell you how long each thing takes

### Silence

-s the output will be only errors

Silence will force bench to not work because output will be close except for errors

## Sintax

Exmples in Example folder

```console
fn main() u8 {
    return 1;
}
```

```console
fn main() u8 {
    return 1 + 1;
}
```
