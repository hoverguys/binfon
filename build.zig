const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("binfon", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "binfon",
        .root_module = module,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Viewer debug app

    const viewer_module = b.addModule("binfon-viewer", .{
        .root_source_file = b.path("src/view.zig"),
        .target = target,
        .optimize = optimize,
    });

    const viewer = b.addExecutable(.{
        .name = "binfon-viewer",
        .root_module = viewer_module,
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
        .root_module = b.addModule("binfon-tests", .{
            .root_source_file = b.path("src/bdf.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_bdf_unit_tests = b.addRunArtifact(bdf_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_bdf_unit_tests.step);
}
