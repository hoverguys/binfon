const std = @import("std");
const bdf = @import("bdf.zig");
const bin = @import("bin.zig");

const FontConfig = struct {
    inputFile: []const u8,
    outputFile: []const u8,
    glyphs: []const u16,
};

pub fn main() !void {
    // Get allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Get args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.err("Usage: {s} <config.json>", .{args[0]});
        std.process.exit(1);
    }

    const inputConfig = args[1];

    // Read config
    const configFile = try std.fs.cwd().readFileAlloc(allocator, inputConfig, std.math.maxInt(usize));
    defer allocator.free(configFile);

    const fontConfig = try readConfig(allocator, configFile);
    defer fontConfig.deinit();

    // Open and parse BDF font
    const input = try std.fs.cwd().openFile(fontConfig.value.inputFile, .{});
    defer input.close();

    var font = try bdf.parse(allocator, input.reader());
    defer font.deinit(allocator);

    // Write output
    const output = try std.fs.cwd().createFile(fontConfig.value.outputFile, .{});
    defer output.close();

    try bin.writeGlyphs(output.writer(), font, fontConfig.value.glyphs);
}

fn readConfig(allocator: std.mem.Allocator, input: []u8) !std.json.Parsed(FontConfig) {
    const fontConfig = try std.json.parseFromSlice(
        FontConfig,
        allocator,
        input,
        .{
            .ignore_unknown_fields = true,
        },
    );

    return fontConfig;
}
