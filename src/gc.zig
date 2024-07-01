const std = @import("std");

const c = @cImport(
    @cInclude("gc.h"),
);

const GCAllocator = struct {
    const Self = @This();

    fn getHeader(ptr: [*]u8) *[*]u8 {
        return @as(*[*]u8, @ptrFromInt(@intFromPtr(ptr) - @sizeOf(usize)));
    }

    fn alloc(
        _: *anyopaque,
        len: usize,
        log2_align: u8,
        _: usize,
    ) ?[*]u8 {
        std.debug.assert(len > 0);

        // Thin wrapper around GC_malloc, overallocate to account for
        // alignment padding and store the original malloc()'ed pointer before
        // the aligned address.
        const alignment = @as(usize, 1) << @as(std.mem.Allocator.Log2Align, @intCast(log2_align));
        const unaligned_ptr = @as([*]u8, @ptrCast(c.GC_malloc(len + alignment - 1 + @sizeOf(usize)) orelse return null));
        const unaligned_addr = @intFromPtr(unaligned_ptr);
        const aligned_addr = std.mem.alignForward(usize, unaligned_addr + @sizeOf(usize), alignment);
        const aligned_ptr = unaligned_ptr + (aligned_addr - unaligned_addr);
        getHeader(aligned_ptr).* = unaligned_ptr;

        return aligned_ptr;
    }

    fn AllocSize(ptr: [*]u8) usize {
        const unaligned_ptr = getHeader(ptr).*;
        const delta = @intFromPtr(ptr) - @intFromPtr(unaligned_ptr);
        return c.GC_size(unaligned_ptr) - delta;
    }

    fn resize(
        _: *anyopaque,
        buf: []u8,
        _: u8,
        new_len: usize,
        _: usize,
    ) bool {
        if (new_len <= buf.len) return true;

        const full_len = AllocSize(buf.ptr);
        if (new_len <= full_len) return true;

        return false;
    }

    fn free(
        _: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        return_address: usize,
    ) void {
        _ = log2_buf_align;
        _ = return_address;
        const unaligned_ptr = getHeader(buf.ptr).*;
        c.GC_free(unaligned_ptr);
    }
};

pub fn allocator() std.mem.Allocator {
    if (c.GC_is_init_called() == 0) {
        c.GC_init();
    }

    return std.mem.Allocator{
        .ptr = undefined,
        .vtable = &.{
            .alloc = GCAllocator.alloc,
            .resize = GCAllocator.resize,
            .free = GCAllocator.free,
        },
    };
}

pub fn getHeapSize() usize {
    return c.GC_get_heap_size();
}

/// Count total memory use in bytes by all allocated blocks.  Acquires
/// the lock.
pub fn getMemoryUse() usize {
    return c.GC_get_memory_use();
}

///  Trigger a full world-stopped collection.  Abort the collection if
///  and when stopFn returns a nonzero value.  stopFn will be
///  called frequently, and should be reasonably fast.  (stopFn is
///  called with the allocation lock held and the world might be stopped;
///  it's not allowed for stopFn to manipulate pointers to the garbage
///  collected heap or call most of GC functions.)  This works even
///  if virtual dirty bits, and hence incremental collection is not
///  available for this architecture.  Collections can be aborted faster
///  than normal pause times for incremental collection.  However,
///  aborted collections do no useful work; the next collection needs
///  to start from the beginning.  stopFn must not be 0.
///  GC_try_to_collect() returns 0 if the collection was aborted (or the
///  collections are disabled), 1 if it succeeded.
pub fn collect(stopFn: c.GC_stop_func) !void {
    if (c.GC_try_to_collect(stopFn) == 0) {
        return error.CollectionAborted;
    }
}

test "GCAllocator" {
    const alloc = allocator();

    try std.heap.testAllocator(alloc);
    try std.heap.testAllocatorAligned(alloc);
    try std.heap.testAllocatorAlignedShrink(alloc);
    try std.heap.testAllocatorLargeAlignment(alloc);
}
