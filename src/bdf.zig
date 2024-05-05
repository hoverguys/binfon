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

const Line = struct {
    command: Command,
    params: []const u8,
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

    var currentName: []const u8 = undefined;
    var currentCharacter: u16 = 0;
    while (true) {
        var lineBuffer: [1024]u8 = undefined;
        const nextLine = try reader.readUntilDelimiterOrEof(&lineBuffer, '\n') orelse break;

        // Parse line
        const line = try parseLine(nextLine);
        switch (line.command) {
            .FONT => {
                font.name = line.params;
                std.log.debug("Font: {s}", .{font.name});
            },
            .FONTBOUNDINGBOX => {
                var boundingBox = std.mem.splitScalar(u8, line.params, ' ');
                font.width = try std.fmt.parseInt(u8, boundingBox.next().?, 10);
                font.height = try std.fmt.parseInt(u8, boundingBox.next().?, 10);

                std.log.debug("Bounding box: {d}x{d}", .{ font.width, font.height });
            },
            .BITMAP => {
                const bitmap = try readBitmap(allocator, font.width, font.height, reader);
                try font.characters.put(currentCharacter, .{
                    .name = try allocator.dupe(u8, currentName),
                    .bitmap = bitmap,
                });
            },
            .STARTCHAR => {
                currentName = line.params;
            },
            .ENCODING => {
                // This probably breaks with custom encodings, not doing anything for now
                currentCharacter = try std.fmt.parseInt(u16, line.params, 10);
            },
            else => {},
        }
    }

    return font;
}

fn parseLine(line: []const u8) !Line {
    const firstSpace = std.mem.indexOfScalar(u8, line, ' ') orelse line.len;
    const command = line[0..firstSpace];

    return .{
        .command = std.meta.stringToEnum(Command, command) orelse Command._IGNORED,
        .params = if (firstSpace == line.len) "" else line[firstSpace + 1 ..],
    };
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
