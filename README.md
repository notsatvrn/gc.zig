# zig-gc

a [Zig](https://ziglang.org/) garbage collector package that provides a garbage collector interface as well as the [bdwgc Boehm GC](https://github.com/ivmai/bdwgc) garbage collector and more.

## Usage

```zig
const gc = @import("zig-gc");

pub fn main() !void {
    // use gc.allocator like any other allocator
    var list = std.ArrayList(u8).init(gc.allocator);

    try list.appendSlice("Hello");
    try list.appendSlice(" World");

    std.debug.print("{s}\n", .{list.items});
    // the program will exit without memory leaks :D
}
```

## Install

1. Add `zig-gc` to the depency list in `build.zig.zon`:

```sh
zig fetch --save git+https://github.com/notsatvrn/zig-gc.git
```

2. Config `build.zig`:

```zig
...
const zig_gc = b.dependency("zig-gc", .{});

exe.root_module.addImport("zig-gc", zig_gc.module("zig-gc"));
...
```

## License

Licensed under the [MIT License](LICENSE).
