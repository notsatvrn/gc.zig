//! A garbage collector interface. This interface signals to the caller that the function was made with the intention of using a garbage collector.

const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const Gc = @This();

pub const Error = Allocator.Error;

gc_allocator: Allocator,

pub fn init(allocator: Allocator) Gc {
    return .{ .allocator = allocator };
}

/// This function is not intended to be called except from within the
/// implementation of an Allocator
pub inline fn rawAlloc(self: Gc, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
    return @call(.always_inline, Allocator.rawAlloc, .{ self.gc_allocator, len, ptr_align, ret_addr });
}

/// This function is not intended to be called except from within the
/// implementation of an Allocator
pub inline fn rawResize(self: Gc, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool {
    return @call(.always_inline, Allocator.rawResize, .{ self.gc_allocator, buf, log2_buf_align, new_len, ret_addr });
}

/// This function is not intended to be called except from within the
/// implementation of an Allocator
pub inline fn rawFree(self: Gc, buf: []u8, log2_buf_align: u8, ret_addr: usize) void {
    return @call(.always_inline, Allocator.rawFree, .{ self.gc_allocator, buf, log2_buf_align, ret_addr });
}

/// Returns a pointer to undefined memory.
/// Call `destroy` with the result to free the memory.
pub fn create(self: Gc, comptime T: type) Error!*T {
    return @call(.always_inline, Allocator.create, .{ self.gc_allocator, T });
}

/// `ptr` should be the return value of `create`, or otherwise
/// have the same address and alignment property.
pub fn destroy(self: Gc, ptr: anytype) void {
    @call(.always_inline, Allocator.destroy, .{ self.gc_allocator, ptr });
}

/// Allocates an array of `n` items of type `T` and sets all the
/// items to `undefined`. Depending on the Allocator
/// implementation, it may be required to call `free` once the
/// memory is no longer needed, to avoid a resource leak. If the
/// `Allocator` implementation is unknown, then correct code will
/// call `free` when done.
///
/// For allocating a single item, see `create`.
pub fn alloc(self: Gc, comptime T: type, n: usize) Error![]T {
    return @call(.always_inline, Allocator.alloc, .{ self.gc_allocator, T, n });
}

pub fn allocWithOptions(
    self: Gc,
    comptime Elem: type,
    n: usize,
    /// null means naturally aligned
    comptime optional_alignment: ?u29,
    comptime optional_sentinel: ?Elem,
) Error!Allocator.AllocWithOptionsPayload(Elem, optional_alignment, optional_sentinel) {
    return @call(.always_inline, Allocator.allocWithOptions, .{ self.gc_allocator, Elem, n, optional_alignment, optional_sentinel });
}

pub fn allocWithOptionsRetAddr(
    self: Gc,
    comptime Elem: type,
    n: usize,
    /// null means naturally aligned
    comptime optional_alignment: ?u29,
    comptime optional_sentinel: ?Elem,
    return_address: usize,
) Error!Allocator.AllocWithOptionsPayload(Elem, optional_alignment, optional_sentinel) {
    return @call(.always_inline, Allocator.allocWithOptionsRetAddr, .{ self.gc_allocator, Elem, n, optional_alignment, optional_sentinel, return_address });
}

/// Allocates an array of `n + 1` items of type `T` and sets the first `n`
/// items to `undefined` and the last item to `sentinel`. Depending on the
/// Allocator implementation, it may be required to call `free` once the
/// memory is no longer needed, to avoid a resource leak. If the
/// `Allocator` implementation is unknown, then correct code will
/// call `free` when done.
///
/// For allocating a single item, see `create`.
pub fn allocSentinel(
    self: Gc,
    comptime Elem: type,
    n: usize,
    comptime sentinel: Elem,
) Error![:sentinel]Elem {
    return @call(.always_inline, Allocator.allocSentinel, .{ self.gc_allocator, Elem, n, sentinel });
}

pub fn alignedAlloc(
    self: Gc,
    comptime T: type,
    /// null means naturally aligned
    comptime alignment: ?u29,
    n: usize,
) Error![]align(alignment orelse @alignOf(T)) T {
    return @call(.always_inline, Allocator.alignedAlloc, .{ self.gc_allocator, T, alignment, n });
}

pub inline fn allocAdvancedWithRetAddr(
    self: Gc,
    comptime T: type,
    /// null means naturally aligned
    comptime alignment: ?u29,
    n: usize,
    return_address: usize,
) Error![]align(alignment orelse @alignOf(T)) T {
    return @call(.always_inline, Allocator.allocAdvancedWithRetAddr, .{ self.gc_allocator, T, alignment, n, return_address });
}

/// Requests to modify the size of an allocation. It is guaranteed to not move
/// the pointer, however the allocator implementation may refuse the resize
/// request by returning `false`.
pub fn resize(self: Gc, old_mem: anytype, new_n: usize) bool {
    return @call(.always_inline, Allocator.resize, .{ self.gc_allocator, old_mem, new_n });
}

/// This function requests a new byte size for an existing allocation, which
/// can be larger, smaller, or the same size as the old memory allocation.
/// If `new_n` is 0, this is the same as `free` and it always succeeds.
pub fn realloc(self: Gc, old_mem: anytype, new_n: usize) t: {
    const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
    break :t Error![]align(Slice.alignment) Slice.child;
} {
    return @call(.always_inline, Allocator.realloc, .{ self.gc_allocator, old_mem, new_n });
}

pub fn reallocAdvanced(
    self: Gc,
    old_mem: anytype,
    new_n: usize,
    return_address: usize,
) t: {
    const Slice = @typeInfo(@TypeOf(old_mem)).Pointer;
    break :t Error![]align(Slice.alignment) Slice.child;
} {
    return @call(.always_inline, Allocator.reallocAdvanced, .{ self.gc_allocator, old_mem, new_n, return_address });
}

/// Free an array allocated with `alloc`. To free a single item,
/// see `destroy`.
pub fn free(self: Gc, memory: anytype) void {
    @call(.always_inline, Allocator.free, .{ self.gc_allocator, memory });
}

/// Copies `m` to newly allocated memory. Caller owns the memory.
pub fn dupe(self: Gc, comptime T: type, m: []const T) Error![]T {
    return @call(.always_inline, Allocator.dupe, .{ self.gc_allocator, T, m });
}

/// Copies `m` to newly allocated memory, with a null-terminated element. Caller owns the memory.
pub fn dupeZ(self: Gc, comptime T: type, m: []const T) Error![:0]T {
    return @call(.always_inline, Allocator.dupeZ, .{ self.gc_allocator, T, m });
}

test "Gc.zig" {
    const allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const gc_alloc = Gc.init(arena.allocator());
    const arena_alloc = arena.allocator();

    try std.testing.expectEqual(@TypeOf(arena_alloc.alloc(u8, 1)), @TypeOf(gc_alloc.alloc(u8, 1)));
    try std.testing.expectEqual(@TypeOf(arena_alloc.create(u8)), @TypeOf(gc_alloc.create(u8)));
    try std.testing.expectEqual(@TypeOf(arena_alloc.allocSentinel(u8, 1, 0)), @TypeOf(gc_alloc.allocSentinel(u8, 1, 0)));
}
