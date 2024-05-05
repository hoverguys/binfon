const std = @import("std");
const bdf = @import("bdf.zig");

pub fn main() !void {
    // Get allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Get args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.log.err("Usage: {s} <input.bdf> <input.zon> <output-dir>", .{args[0]});
        std.process.exit(1);
    }

    const inputFile = args[1];
    const outputPath = args[2];
    _ = outputPath; // autofix

    // Read font
    const input = try std.fs.cwd().openFile(inputFile, .{});
    defer input.close();

    var font = try bdf.parse(allocator, input.reader());
    defer font.deinit(allocator);
}
