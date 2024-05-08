const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
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
    _ = b.addModule("binfon", .{
        .root_source_file = .{ .path = "src/lib.zig" },
    });

    // Library
    const libbinfon = buildLibrary(b, .{
        .target = target,
        .optimize = optimize,
    });

    const libzimalloc_install = b.addInstallArtifact(libbinfon, .{});
    b.getInstallStep().dependOn(&libzimalloc_install.step);
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
