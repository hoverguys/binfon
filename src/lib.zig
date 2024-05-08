const std = @import("std");
const bdf = @import("bdf.zig");
const bin = @import("bin.zig");

pub const Font = bdf.Font;
pub const writeGlyphs = bin.writeGlyphs;

pub fn convert(allocator: std.mem.Allocator, input: anytype, output: anytype, glyphs: []const u16) !void {
    var font = try bdf.Font.parse(allocator, input);
    defer font.deinit(allocator);

    try bin.writeGlyphs(output, font, glyphs);
}
