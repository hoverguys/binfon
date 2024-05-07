const std = @import("std");
const bdf = @import("bdf.zig");

const WriteError = error{UnknownGlyph};

pub fn writeGlyphs(output: anytype, font: bdf.Font, glyphs: []const u16) !void {
    for (glyphs) |glyph| {
        const character = font.characters.get(glyph) orelse {
            std.log.err("Unknown glyph: {d}", .{glyph});
            return WriteError.UnknownGlyph;
        };

        for (character.bitmap) |line| {
            _ = try output.write(line);
        }
    }
}
