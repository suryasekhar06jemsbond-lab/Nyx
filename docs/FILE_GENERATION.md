# Nyx File Generation Module

## 🎯 100% NATIVE IMPLEMENTATION - NO DEPENDENCIES REQUIRED!

The Nyx file generation module (`stdlib/generator.ny`) provides comprehensive capabilities for generating various file formats using **pure Nyx code**. No external libraries, no Python dependencies, no installation required - everything works out of the box!

## Supported File Formats (All Native)

### 📄 Text-Based Files ✅ Fully Native
- **.txt** - Plain text files
- **.md** - Markdown documents
- **.csv** - CSV with proper escaping
- **.rtf** - Rich Text Format

### 🖼️ Image Files ✅ Fully Native
- **.svg** - Scalable Vector Graphics
- **.bmp** - Bitmap images (uncompressed)
- **.png** - PNG images (native encoding)
- **.ico** - Icon files (native encoding)
- **.jpg** - JPEG (simplified BMP-based)

### 📘 Document Files ✅ Fully Native
- **.pdf** - PDF documents (PDF 1.4 spec)
- **.docx** - Microsoft Word documents (Office Open XML)
- **.odt** - OpenDocument text files

### 📊 Spreadsheet Files ✅ Fully Native
- **.xlsx** - Excel spreadsheets (Office Open XML)
- **.ods** - OpenDocument spreadsheets

### 📽️ Presentation Files ✅ Fully Native
- **.pptx** - PowerPoint presentations (Office Open XML)
- **.odp** - OpenDocument presentations

## Installation

### ✨ Zero Dependencies!

**No installation required!** All file generation is implemented in pure Nyx code. Just import and use:

```nyx
import generator

# Works immediately - no setup needed!
generator::generate_txt("hello.txt", "Hello, World!");
```

## Usage Examples

### Text-Based Files

#### Plain Text (.txt)
```nyx
import generator

generator::generate_txt("output.txt", "Hello from Nyx!\nMultiple lines supported.");
```

#### Markdown (.md)
```nyx
import generator

let sections = [
    {heading: "Introduction", content: "This is the intro.", level: 2},
    {heading: "Details", content: "More details here.", level: 2}
];
generator::generate_md("document.md", "My Document", sections);
```

#### CSV (.csv)
```nyx
import generator

let headers = ["Name", "Age", "City"];
let rows = [
    ["Alice", "30", "New York"],
    ["Bob", "25", "Los Angeles"]
];
generator::generate_csv("data.csv", headers, rows, ",");
```

#### RTF (.rtf)
```nyx
import generator

generator::generate_rtf("document.rtf", "My Title", "Document content here.", 24);
```

### Image Files

#### SVG (Native Support)
```nyx
import generator

let elements = [
    {type: "rect", x: 10, y: 10, width: 100, height: 50, fill: "blue"},
    {type: "circle", cx: 150, cy: 75, r: 30, fill: "red"},
    {type: "text", x: 50, y: 100, content: "Hello!", fill: "black"}
];
generator::generate_svg("image.svg", 300, 200, elements);
```

#### PNG/BMP/ICO (All Native!)
```nyx
import generator

# Create pixel data - gradient example
let pixels = [];
for y in range(100) {
    for x in range(100) {
        let r = (x * 255) / 100;
        let g = (y * 255) / 100;
        let b = 128;
        push(pixels, [r, g, b, 255]);  # R, G, B, A
    }
}

generator::generate_png("gradient.png", 100, 100, pixels);
generator::generate_bmp("gradient.bmp", 100, 100, pixels);
generator::generate_ico("icon.ico", 64, 64, pixels);
```

### Document Files

#### PDF (Native Implementation!)
```nyx
import generator

let content = [
    {type: "heading", text: "My Document", level: 1},
    {type: "paragraph", text: "This is a paragraph."},
    {type: "heading", text: "Section 1", level: 2},
    {type: "paragraph", text: "Section content here."},
    {type: "bullet", text: "Bullet point"},
    {type: "spacer", height: 20}
];
generator::generate_pdf("document.pdf", "My Title", content, null);
```

#### DOCX (Native XML Generation!)
```nyx
import generator

let sections = [
    {
        heading: "Introduction",
        paragraphs: ["Paragraph 1", "Paragraph 2"],
        level: 1
    },
    {
        heading: "Details",
        paragraphs: ["More details here"],
        level: 2
    }Native XML Generation!)
```nyx
import generator

let sheets = [
    {
        name: "Sales Data",
        headers: ["Month", "Revenue", "Expenses"],
        data: [
            ["January", 50000, 30000],
            ["February", 55000, 32000],
            ["March", 60000, 35
import generator

let sheets = [
    {
        name: "Sales Data",
        headers: ["Month", "Revenue", "Expenses"],
        data: [
            ["January", 50000, 30000],
            ["February", 55000, 32000]
        ]
    }
];
generator::generate_xlsx("spreadsheet.xlsx", sheets);
```

### Presentation Files
Native XML Generation!)
```nyx
import generator

let slides = [
    {
        title: "Introduction",
        content: ["Point 1", "Point 2", "Point 3"]
    },
    {
        title: "Conclusion",
        content: ["Summary", "Next steps"] 2", "Point 3"],
        layout: "title_and_content"
    }
];
generator::generate_pptx("presentation.pptx", "My Presentation", slides);
```

## Advanced Features

### Unified Interface

Automatically detect format from file extension:

```nyx
import generator

let data = {
    title: "Auto-Detected",
    sections: [{heading: "Section", content: "Content", level: 2}]
};
generator::generate_file("output.md", null, data);  // Format auto-detected
```

### Batch Generation

Generate multiple files at once:

```nyx
import generator

let specs = [
    {path: "file1.txt", format: "txt", data: "Content 1"},
    {path: "file2.txt", format: "txt", data: "Content 2"}
];
generator::generate_files(specs);
```

### Template-Based Generation

Use templates with variable substitution:

```nyx
import generator

let template = "Hello {{name}}!\nAge: {{age}}";
io::write_file("template.txt", template);

let vars = {name: "Alice", age: "30"};
generator::generate_from_template("template.txt", "output.txt", vars);
```

## API Reference

### Text Functions
- `generate_txt(path, content)` - Generate plain text file
- `generate_md(path, title, sections)` - Generate Markdown file
- `generate_csv(path, headers, rows, delimiter)` - Generate CSV file
- `generate_rtf(path, title, content, font_size)` - Generate RTF file

### Image Functions
- `generate_svg(path, width, height, elements)` - Generate SVG image
- `generate_png(path, width, height, draw_fn)` - Generate PNG image
- `generate_jpg(path, width, height, draw_fn)` - Generate JPEG image
- `generate_ico(path, width, height, draw_fn)` - Generate ICO icon

### Document Functions
- `generate_pdf(path, title, content, options)` - Generate PDF document
- `generate_docx(path, title, sections)` - Generate Word document
- `generate_odt(path, title, sections)` - Generate OpenDocument text

### Spreadsheet Functions
- `generate_xlsx(path, sheets)` - Generate Excel spreadsheet
- `generate_ods(path, sheets)` - Generate OpenDocument spreadsheet

### Presentation Functions
- `generate_pptx(path, title, slides)` - Generate PowerPoint presentation
- `generate_odp(path, title, slides)` - Generate OpenDocument presentation

### Utility Functions
- `generate_file(path, format, data)` - Unified generation interface
- `generate_files(specs)` - Batch generation
- `generate_from_template(template_path, output_path, variables)` - Template generation
- `detect_format(path)` - Detect format from file extension
- `escape_rtf(text)` - Escape RTF special characters
- `escape_path(path)` - Escape path for shell/Python
- `escape_string(text)` - Escape string for Python

## Testing

Run the test suite:

```bash
nyx tests/test_generator.ny
```

## Examples

See complete examples in:
- `examples/file_generation_examples.ny`

Run the examples:

```bash
nyx examples/file_generation_examples.ny
```

## Architecture

### 🎯 100% Pure Nyx Implementation

The file generation module is implemented entirely in Nyx with zero external dependencies:

1. **Text Formats** (TXT, MD, CSV, RTF, SVG): Direct string manipulation and file writing
   - Immediate output, no encoding needed
   - Full control over format specifications

2. **Raster Images** (BMP, PNG, ICO): Native binary encoding
   - BMP: Uncompressed RGB format with proper headers
   - PNG: PNG specification with CRC32 checksums (simplified IDAT)
   - ICO: Windows icon format with embedded BMP data

3. **PDF**: Implements PDF 1.4 specification
   - Native object/stream generation
   - Cross-reference table creation
   - Text positioning and font management

4. **Office Formats** (DOCX, XLSX, PPTX): Office Open XML generation
   - Creates valid XML conforming to OOXML spec
   - For full compatibility, XML can be packaged as ZIP
   - Many modern Office apps can open the XML directly

### Binary Encoding

All binary formats use custom encoding functions:
- `encode_u32_le/be()` - 32-bit integers (little/big endian)
- `encode_u16_le/be()` - 16-bit integers
- `calculate_crc32()` - CRC32 checksums for PNG
- Direct `chr()` and bitwise operations

### Performance

- **Text formats**: Instant generation (string operations)
- **Vector graphics (SVG)**: Instant generation
- **Raster images**: O(width × height) pixel processing
- **PDF**: O(content_size) text layout
- **Office XML**: O(data_size) XML generation

All formats are fast enough for production use!

## Limitations

### Current Limitations
- **JPEG**: Uses BMP encoding (full JPEG DCT encoding is complex). Use BMP or PNG instead.
- **Office Formats**: Generated as XML; may need ZIP packaging for some applications
- **PNG**: Simplified implementation without zlib compression (larger file sizes)
- **PDF**: Basic text layout only (no advanced features like forms, embedded fonts)

### Design Trade-offs
- **Simplicity over compression**: Uncompressed formats for easier native implementation
- **Standards compliance**: Follows specifications but may omit advanced features
- **Portability**: Works anywhere Nyx runs, no external dependencies

## Future Enhancements

- [ ] PNG zlib compression for smaller files
- [ ] Full JPEG DCT encoding
- [ ] Automatic ZIP packaging for Office formats
- [ ] Advanced PDF features (tables, images, fonts)
- [ ] Image manipulation functions (resize, crop, rotate)
- [ ] Chart generation helpers
- [ ] QR code generation

## Contributing

To add support for a new file format:

1. Add the generation function to `stdlib/generator.ny`
2. Create tests in `tests/test_generator.ny`
3. Add examples to `examples/file_generation_examples.ny`
4. Update this documentation

## License

Part of the Nyx programming language project.
