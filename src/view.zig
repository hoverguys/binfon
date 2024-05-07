const std = @import("std");

pub fn main() !void {
    // Get allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Get args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    std.debug.print("args: {s}\n", .{args});
    if (args.len < 4) {
        std.log.err("Usage: {s} <glyph width (eg. 8)> <glyph height (eg. 16)> <file.font.bin>", .{args[0]});
        std.process.exit(1);
    }

    const bytesPerRow = (try std.fmt.parseInt(u8, args[1], 10)) / 8;
    const glyphHeight = try std.fmt.parseInt(u8, args[2], 10);

    // Open font
    const file = try std.fs.cwd().openFile(args[3], .{});
    defer file.close();

    // Read byte by byte
    var reader = file.reader();
    var i: u16 = 0;
    while (true) {
        std.debug.print(" -- GLYPH {d} / 0x{x} --\n", .{ i, i });
        for (0..glyphHeight) |y| {
            for (0..bytesPerRow) |_| {
                const next = try reader.readByte();
                std.debug.print("{x}: ", .{y});
                for (0..8) |x| {
                    if (@as(u1, @truncate(next >> @truncate(7 - x))) == 1) {
                        std.debug.print("*", .{});
                    } else {
                        std.debug.print(" ", .{});
                    }
                }
                std.debug.print(" ", .{});
            }
            std.debug.print("\n", .{});
        }

        i += 1;
    }
}
