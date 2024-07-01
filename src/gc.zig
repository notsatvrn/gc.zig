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

test "GCAllocator" {
    const alloc = allocator();

    try std.heap.testAllocator(alloc);
    try std.heap.testAllocatorAligned(alloc);
    try std.heap.testAllocatorAlignedShrink(alloc);
    try std.heap.testAllocatorLargeAlignment(alloc);
}
