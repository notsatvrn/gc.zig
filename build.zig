const std = @import("std");

pub fn build(b: *std.Build) void {
    blk: {
        var dir = std.fs.cwd().openDir("bdwgc", .{
            .iterate = true,
        }) catch break :blk;
        defer dir.close();
        var iter = dir.iterate();
        if (iter.next() catch break :blk == null) {
            std.debug.print("submodule bdwgc missing. Please run `git submodule update --init --recursive`.\n", .{});
            return;
        }
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    {
        const lib = b.addStaticLibrary(.{
            .name = "garbage-collector",
            .root_source_file = b.path("src/gc.zig"),
            .target = target,
            .optimize = optimize,
        });
        setupBdwgcDependencies(lib, b, target);

        b.installArtifact(lib);
    }
    {
        const lib_unit_tests = b.addTest(.{
            .root_source_file = b.path("src/gc.zig"),
            .target = target,
            .optimize = optimize,
        });
        setupBdwgcDependencies(lib_unit_tests, b, target);

        const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_lib_unit_tests.step);
    }
}

fn setupBdwgcDependencies(
    compile: *std.Build.Step.Compile,
    b: *std.Build,
    target: std.Build.ResolvedTarget,
) void {
    compile.linkLibC();
    compile.addIncludePath(b.path("bdwgc/include"));

    if (target.result.isDarwin()) compile.linkFramework("Foundation");

    const c_source_files = [_][]const u8{
        "allchblk.c",
        "alloc.c",
        "blacklst.c",
        "dbg_mlc.c",
        "dyn_load.c",
        "finalize.c",
        "headers.c",
        "mach_dep.c",
        "malloc.c",
        "mallocx.c",
        "mark.c",
        "mark_rts.c",
        "misc.c",
        "new_hblk.c",
        "obj_map.c",
        "os_dep.c",
        "ptr_chck.c",
        "reclaim.c",
        "typd_mlc.c",
    };

    inline for (c_source_files) |src| {
        compile.addCSourceFile(.{
            .file = b.path("bdwgc/" ++ src),
        });
    }
}
