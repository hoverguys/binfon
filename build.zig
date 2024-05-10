const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "binfon",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Viewer debug app
    const viewer = b.addExecutable(.{
        .name = "binfon-viewer",
        .root_source_file = b.path("src/view.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(viewer);

    const view_cmd = b.addRunArtifact(viewer);
    view_cmd.step.dependOn(b.getInstallStep());

    const view_step = b.step("view", "Run the app");
    view_step.dependOn(&view_cmd.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
        view_cmd.addArgs(args);
    }

    // Tests
    const bdf_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/bdf.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_bdf_unit_tests = b.addRunArtifact(bdf_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_bdf_unit_tests.step);

    // Module
    addModule(b);

    // Library
    const libbinfon = buildLibrary(b, .{
        .target = target,
        .optimize = optimize,
    });

    const libzimalloc_install = b.addInstallArtifact(libbinfon, .{});
    b.getInstallStep().dependOn(&libzimalloc_install.step);
}

/// Module function for depending on the binfon module
pub fn addModule(b: *std.Build) void {
    _ = b.addModule("binfon", .{
        .root_source_file = .{ .path = "src/lib.zig" },
    });
}

const ModuleOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Mode,
    linkage: std.builtin.LinkMode = .dynamic,
    pic: ?bool = null,
};

fn buildLibrary(b: *std.Build, options: ModuleOptions) *std.Build.Step.Compile {
    const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };

    const library = switch (options.linkage) {
        .dynamic => b.addSharedLibrary(.{
            .name = "binfon",
            .root_source_file = .{ .path = "src/lib.zig" },
            .version = version,
            .target = options.target,
            .optimize = options.optimize,
            .pic = options.pic,
        }),
        .static => b.addStaticLibrary(.{
            .name = "binfon",
            .root_source_file = .{ .path = "src/lib.zig" },
            .version = version,
            .target = options.target,
            .optimize = options.optimize,
            .pic = options.pic,
        }),
    };

    return library;
}
