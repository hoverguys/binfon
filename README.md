# Absolutely Worthless Binfon

Takes all your precious fonts and puts them in the BIN!

Allows embedding of bitmap fonts into easily embeddable binary blobs.

The inputs must be a .bdf file and a .json configuration file. The JSON configuration file must be formatted as follows:

```json
{
	"inputFile": "path/to/input.bdf",
	"outputFile": "path/to/output.bin",
	"glyphs": [
		<list of glyphs by ENCODING value>
	]
}
```

The output bin will contain all the glyphs in the order they are specified in the configuration without any gaps. Everything is packed using byte padding (exactly as in the BDF input file). Eg. if your font is 8x3, every character will be 3 bytes (1 byte x 3 rows), if your font is 10x8, every character will be 16 bytes (2 bytes x 10 rows).

The formula to seek to a specific char should be roughly:
```rust
const ENCODED_WIDTH = <ceil(font.width / 8)>;
const GLYPH_HEIGHT = <font.height>;

fn printChar(characterIndex: usize) void {
	const baseOffset = ENCODED_WIDTH*GLYPH_HEIGHT*characterIndex;
	for (0..GLYPH_HEIGHT) |rowIndex| {
		const rowIndex = baseOffset + rowIndex * ENCODED_WIDTH;
		const bytes = binaryBlob[rowIndex..rowIndex+ENCODED_WIDTH];
		/* drawing routine here */
	}
}
```

for width ≤ 8px, code can be simplified to:
```rust
const GLYPH_HEIGHT = <font.height>;

fn printChar(characterIndex: usize) void {
	const baseOffset = GLYPH_HEIGHT*characterIndex;
	for (0..GLYPH_HEIGHT) |rowIndex| {
		const byte = binaryBlob[baseOffset + rowIndex];
		/* drawing routine here */
	}
}
```

## License

`AGPL-3.0-only`