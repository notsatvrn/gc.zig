# gc.zig
a [Zig](https://ziglang.org/) garbage collector interface for the [bdwgc Boehm GC](https://github.com/ivmai/bdwgc) garbage collector.

## Usage

```zig
const zig_gc = @import("zig_gc");

pub fn main() !void {
    const gc = zig_gc.BdwGarbageCollector.allocator();

    var list = std.ArrayList(u8).init(gc);

    try list.append("Hello");
    try list.append("World");

    std.debug.print("{s}\n", .{list.items});
    // the program will exit without memory leaks :D
}
```

## install

1. Add to the depency list in `build.zig.zon`: 

```sh
zig fetch --save https://github.com/jinzhongjia/zTroy/archive/main.tar.gz
```

2. Config `build.zig`:

```zig
...
const zig_gc = b.dependency("zig_gc", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zig_gc", zTroy.module("zig_gc"));
...
```


## License

Licensed under the [MIT License](LICENSE).