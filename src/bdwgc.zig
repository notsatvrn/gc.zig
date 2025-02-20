const std = @import("std");
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

const c = @cImport(
    @cInclude("gc.h"),
);

const Self = @This();

fn getHeader(ptr: [*]u8) *[*]u8 {
    return @as(*[*]u8, @ptrFromInt(@intFromPtr(ptr) - @sizeOf(usize)));
}

fn alloc(
    _: *anyopaque,
    len: usize,
    alignment: Alignment,
    _: usize,
) ?[*]u8 {
    std.debug.assert(len > 0);

    // Thin wrapper around GC_malloc, overallocate to account for
    // alignment padding and store the original malloc()'ed pointer before
    // the aligned address.
    const align_ = alignment.toByteUnits();
    const unaligned_ptr: [*]u8 = @ptrCast(c.GC_malloc(len + align_ - 1 + @sizeOf(usize)) orelse return null);
    const unaligned_addr = @intFromPtr(unaligned_ptr);
    const aligned_addr = std.mem.alignForward(usize, unaligned_addr + @sizeOf(usize), align_);
    const aligned_ptr = unaligned_ptr + (aligned_addr - unaligned_addr);
    getHeader(aligned_ptr).* = unaligned_ptr;

    return aligned_ptr;
}

fn allocSize(ptr: [*]u8) usize {
    const unaligned_ptr = getHeader(ptr).*;
    const delta = @intFromPtr(ptr) - @intFromPtr(unaligned_ptr);
    return c.GC_size(unaligned_ptr) - delta;
}

fn resize(
    _: *anyopaque,
    buf: []u8,
    _: Alignment,
    new_len: usize,
    _: usize,
) bool {
    if (new_len <= buf.len) return true;

    const full_len = allocSize(buf.ptr);
    if (new_len <= full_len) return true;

    return false;
}

fn remap(
    _: *anyopaque,
    buf: []u8,
    alignment: Alignment,
    new_len: usize,
    _: usize,
) ?[*]u8 {
    if (new_len <= buf.len) return buf.ptr;

    const full_len = allocSize(buf.ptr);
    if (new_len <= full_len) return buf.ptr;

    const align_ = alignment.toByteUnits();
    const old_unaligned_ptr = getHeader(buf.ptr).*;
    const unaligned_ptr: [*]u8 = @ptrCast(c.GC_realloc(old_unaligned_ptr, new_len + align_ - 1 + @sizeOf(usize)) orelse return null);
    const unaligned_addr = @intFromPtr(unaligned_ptr);
    const aligned_addr = std.mem.alignForward(usize, unaligned_addr + @sizeOf(usize), align_);
    const aligned_ptr = unaligned_ptr + (aligned_addr - unaligned_addr);
    getHeader(aligned_ptr).* = unaligned_ptr;

    return aligned_ptr;
}

fn free(
    _: *anyopaque,
    buf: []u8,
    alignment: Alignment,
    return_address: usize,
) void {
    _ = alignment;
    _ = return_address;
    const unaligned_ptr = getHeader(buf.ptr).*;
    c.GC_free(unaligned_ptr);
}

pub fn allocator() Allocator {
    if (c.GC_is_init_called() == 0)
        c.GC_init();

    return Allocator{
        .ptr = undefined,
        .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        },
    };
}

/// Returns the current heap size of used memory.
pub fn getHeapSize() usize {
    return c.GC_get_heap_size();
}

/// Count total memory use in bytes by all allocated blocks.  Acquires
/// the lock.
pub fn getMemoryUse() usize {
    return c.GC_get_memory_use();
}

/// Disable garbage collection.
pub fn disable() void {
    c.GC_disable();
}

/// Enables garbage collection. GC is enabled by default so this is
/// only useful if you called disable earlier.
pub fn enable() void {
    c.GC_enable();
}

/// Performs a full, stop-the-world garbage collection. With leak detection
/// enabled this will output any leaks as well.
pub fn collect() void {
    c.GC_gcollect();
}

/// Perform some garbage collection. Returns zero when work is done.
pub fn collectLittle() usize {
    return @intCast(c.GC_collect_a_little());
}

// Perform the collector shutdown.  (E.g. dispose critical sections on
// Win32 target.)  A duplicate invocation is a no-op.  GC_INIT should
// not be called after the shutdown.  See also GC_win32_free_heap().
pub fn deinit() void {
    c.GC_deinit();
}

test "GCAllocator" {
    const gc_alloc = allocator();

    _ = getHeapSize();
    _ = getMemoryUse();
    disable();
    enable();
    collect();
    _ = collectLittle();

    try std.heap.testAllocator(gc_alloc);
    try std.heap.testAllocatorAligned(gc_alloc);
    try std.heap.testAllocatorAlignedShrink(gc_alloc);
    try std.heap.testAllocatorLargeAlignment(gc_alloc);
}
