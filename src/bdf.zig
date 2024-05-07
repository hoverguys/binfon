const std = @import("std");

const Bitmap = [][]u8;

const Character = struct {
    name: []u8,
    bitmap: Bitmap,

    pub fn deinit(self: *Character, allocator: std.mem.Allocator) void {
        for (self.bitmap) |line| {
            allocator.free(line);
        }
        allocator.free(self.bitmap);
        allocator.free(self.name);
    }
};
const CharacterMap = std.AutoHashMap(u16, Character);

const Font = struct {
    name: []const u8,
    height: u8,
    width: u8,
    characters: CharacterMap,

    pub fn deinit(self: *Font, allocator: std.mem.Allocator) void {
        var iterator = self.characters.valueIterator();
        while (iterator.next()) |char| {
            char.deinit(allocator);
        }
        allocator.free(self.name);
        self.characters.deinit();
    }
};

const Command = enum {
    FONT,
    FONTBOUNDINGBOX,
    ENCODING,
    BITMAP,
    STARTCHAR,
    _IGNORED,
};

const ParsedCommand = union(Command) {
    FONT: []const u8,
    FONTBOUNDINGBOX: struct { width: u8, height: u8 },
    ENCODING: u16,
    BITMAP: void,
    STARTCHAR: []const u8,
    _IGNORED: void,
};

pub fn parse(allocator: std.mem.Allocator, bdf: anytype) !Font {
    var font: Font = .{
        .name = undefined,
        .height = 0,
        .width = 0,
        .characters = CharacterMap.init(allocator),
    };

    var bufferedReader = std.io.bufferedReader(bdf);
    var reader = bufferedReader.reader();

    var arenaAllocator = std.heap.ArenaAllocator.init(allocator);
    defer arenaAllocator.deinit();

    var currentName: []u8 = undefined;
    var currentCharacter: u16 = 0;
    while (true) {
        var lineBuffer: [1024]u8 = undefined;
        const nextLine = try reader.readUntilDelimiterOrEof(&lineBuffer, '\n') orelse break;

        // Parse line
        const line = try parseLine(arenaAllocator.allocator(), nextLine);
        switch (line) {
            .FONT => |name| {
                font.name = try allocator.dupe(u8, name);
                std.log.debug("Font: {s}", .{name});
            },
            .FONTBOUNDINGBOX => |box| {
                font.width = box.width;
                font.height = box.height;
                std.log.debug("Bounding box: {d}x{d}", .{ box.width, box.height });
            },
            .STARTCHAR => |name| {
                currentName = try allocator.dupe(u8, name);
            },
            .ENCODING => |num| {
                currentCharacter = num;
            },
            .BITMAP => {
                const bitmap = try readBitmap(allocator, font.width, font.height, reader);
                try font.characters.put(currentCharacter, .{
                    .name = currentName,
                    .bitmap = bitmap,
                });
            },
            ._IGNORED => {},
        }
    }

    return font;
}

fn parseLine(allocator: std.mem.Allocator, line: []const u8) !ParsedCommand {
    const firstSpace = std.mem.indexOfScalar(u8, line, ' ') orelse line.len;
    const command = std.meta.stringToEnum(Command, line[0..firstSpace]) orelse Command._IGNORED;

    const rest = if (firstSpace == line.len) "" else line[firstSpace + 1 ..];

    switch (command) {
        .ENCODING => {
            return ParsedCommand{ .ENCODING = try std.fmt.parseInt(u16, rest, 10) };
        },
        .BITMAP => {
            return ParsedCommand{ .BITMAP = {} };
        },
        .STARTCHAR => {
            return ParsedCommand{ .STARTCHAR = try allocator.dupe(u8, rest) };
        },
        .FONT => {
            return ParsedCommand{ .FONT = try allocator.dupe(u8, rest) };
        },
        .FONTBOUNDINGBOX => {
            var boundingBox = std.mem.splitScalar(u8, rest, ' ');
            return ParsedCommand{ .FONTBOUNDINGBOX = .{
                .width = try std.fmt.parseInt(u8, boundingBox.next().?, 10),
                .height = try std.fmt.parseInt(u8, boundingBox.next().?, 10),
            } };
        },
        ._IGNORED => {
            return ParsedCommand{ ._IGNORED = {} };
        },
    }
}

test "parseLine: Parses FONTBOUNDINGBOX correctly" {
    const allocator = std.testing.allocator;
    const line = "FONTBOUNDINGBOX 10 20";
    const parsed = try parseLine(allocator, line);

    try std.testing.expectEqual(ParsedCommand{ .FONTBOUNDINGBOX = .{ .width = 10, .height = 20 } }, parsed);
}

test "parseLine: Parses ENCODING correctly" {
    const allocator = std.testing.allocator;
    const line = "ENCODING 123";
    const parsed = try parseLine(allocator, line);

    try std.testing.expectEqual(ParsedCommand{ .ENCODING = 123 }, parsed);
}

test "parseLine: Parses STARTCHAR correctly" {
    const allocator = std.testing.allocator;
    const line = "STARTCHAR ABC";
    const parsed = try parseLine(allocator, line);

    switch (parsed) {
        .STARTCHAR => |name| {
            try std.testing.expectEqualStrings("ABC", name);
            allocator.free(name);
        },
        else => unreachable,
    }
}

test "parseLine: Parses FONT correctly" {
    const allocator = std.testing.allocator;
    const line = "FONT ABC";
    const parsed = try parseLine(allocator, line);

    switch (parsed) {
        .FONT => |name| {
            try std.testing.expectEqualStrings("ABC", name);
            allocator.free(name);
        },
        else => unreachable,
    }
}

test "parseLine: Parses BITMAP correctly" {
    const allocator = std.testing.allocator;
    const line = "BITMAP";
    const parsed = try parseLine(allocator, line);

    try std.testing.expectEqual(ParsedCommand{ .BITMAP = {} }, parsed);
}

fn readBitmap(
    allocator: std.mem.Allocator,
    width: u8,
    height: u8,
    reader: anytype,
) !Bitmap {
    var lineIndex: u8 = 0;

    var char = try allocator.alloc([]u8, height);
    errdefer {
        for (0..lineIndex) |i| {
            allocator.free(char[i]);
        }
        allocator.free(char);
    }

    // Allocate memory for the parsed bitmap
    var line: []u8 = try allocator.alloc(u8, width / 8);
    defer allocator.free(line);

    // Read lines until ENDCHAR
    while (true) {
        std.debug.assert(lineIndex < height + 1);

        // Read the next line
        var lineBuffer: [128]u8 = undefined;
        const nextLine = try reader.readUntilDelimiterOrEof(&lineBuffer, '\n') orelse break;

        // If we encounter the magic string, we're done
        if (std.mem.eql(u8, nextLine, "ENDCHAR")) {
            break;
        }

        // Parse every 2 char as a hexadecimal number
        var i: usize = 0;
        while (i < nextLine.len) : (i += 2) {
            const hex = try std.fmt.parseInt(u8, nextLine[i .. i + 2], 16);
            line[i / 2] = hex;
        }

        // Copy over to the array (this memory must be freed later)
        char[lineIndex] = try allocator.dupe(u8, line);
        lineIndex += 1;
    }

    return char;
}

test "readBitmap: Reads bitmap correctly for < 8px wide glyphs" {
    const allocator = std.testing.allocator;

    var reader = std.io.fixedBufferStream("10\n20\n30\nENDCHAR");

    const bitmap = try readBitmap(allocator, 8, 3, reader.reader());
    try std.testing.expectEqual(@as(usize, 3), bitmap.len);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x10}, bitmap[0]);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x20}, bitmap[1]);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x30}, bitmap[2]);

    for (bitmap) |line| {
        allocator.free(line);
    }
    allocator.free(bitmap);
}

test "readBitmap: Reads bitmap correctly for > 8px wide glyphs" {
    const allocator = std.testing.allocator;

    var reader = std.io.fixedBufferStream("1234\nABDC\nENDCHAR");

    const bitmap = try readBitmap(allocator, 16, 2, reader.reader());
    try std.testing.expectEqual(@as(usize, 2), bitmap.len);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x12, 0x34 }, bitmap[0]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xAB, 0xDC }, bitmap[1]);

    for (bitmap) |line| {
        allocator.free(line);
    }
    allocator.free(bitmap);
}
