//! A garbage collector interface.
//! This interface signals to the caller that the function was made with the intention of using a garbage collector.

const std = @import("std");
const Allocator = std.mem.Allocator;

const Self = @This();

allocator: Allocator,

/// the allocator should be a garbage collector
/// or leave the memory management to the caller
pub fn init(allocator: Allocator) Self {
    return .{
        .allocator = allocator,
    };
}
