pub const Gc = @import("Gc.zig");
pub const BdwGarbageCollector = @import("bdwgc.zig");

const std = @import("std");

test {
    std.testing.refAllDecls(@This());
}
