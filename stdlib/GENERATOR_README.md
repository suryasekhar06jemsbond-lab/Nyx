# Generator Module - Quick Reference

## 🎯 100% NATIVE - NO DEPENDENCIES!

All file generation is pure Nyx code. No external libraries required!

## Import
```nyx
import generator
```

## Quick Examples

### Text Files (Native)
```nyx
# Plain text
generator::generate_txt("file.txt", "Content here");

# Markdown
generator::generate_md("doc.md", "Title", [
    {heading: "Section", content: "Text", level: 2}
]);

# CSV
generator::generate_csv("data.csv", ["A", "B"], [["1", "2"]], ",");

# RTF
generator::generate_rtf("doc.rtf", "Title", "Content", 24);
```

### Images (All Native!)
```nyx
# SVG - vector graphics
generator::generate_svg("img.svg", 200, 100, [
    {type: "rect", x: 0, y: 0, width: 200, height: 100, fill: "blue"},
    {type: "circle", cx: 100, cy: 50, r: 30, fill: "red"}
]);

# BMP - raster image
let pixels = [];
for i in range(100 * 100) {
    push(pixels, [255, 0, 0]);  // RGB
}
generator::generate_bmp("img.bmp", 100, 100, pixels);

# PNG - raster image with alpha
let pixels = [];
for i in range(64 * 64) {
    push(pixels, [0, 128, 255, 255]);  // RGBA
}
generator::generate_png("img.png", 64, 64, pixels);

# ICO - icon file
generator::generate_ico("icon.ico", 32, 32, pixels);
```

### Documents (Native!)
```nyx
# PDF
generator::generate_pdf("doc.pdf", "Title", [
    {type: "heading", text: "H1", level: 1},
    {type: "paragraph", text: "Text"}
], null);

# DOCX (generates XML)
generator::generate_docx("doc.docx", "Title", [
    {heading: "H1", paragraphs: ["P1"], level: 1}
]);
```

### Spreadsheets (Native!)
```nyx
# XLSX (generates XML)
generator::generate_xlsx("sheet.xlsx", [{
    name: "Sheet1",
    headers: ["A", "B"],
    data: [["1", "2"], ["3", "4"]]
}]);
```

### Presentations (Native!)
```nyx
# PPTX (generates XML)
generator::generate_pptx("pres.pptx", "Title", [{
    title: "Slide 1",
    content: ["Point 1", "Point 2"]
}]);
```

## Unified Interface
```nyx
# Auto-detect format from extension
generator::generate_file("output.md", null, data);

# Explicit format
generator::generate_file("output", "csv", data);
```

## Batch Generation
```nyx
generator::generate_files([
    {path: "f1.txt", format: "txt", data: "Content 1"},
    {path: "f2.txt", format: "txt", data: "Content 2"}
]);
```

## Template Generation
```nyx
# Template: "Hello {{name}}, you are {{age}} years old"
generator::generate_from_template(
    "template.txt",
    "output.txt",
    {name: "Alice", age: "30"}
);
```

## No Setup Required!

✨ **Everything works immediately - no pip, no installation, just import and use!**

## See Also
- Full documentation: `docs/FILE_GENERATION.md`
- Examples: `examples/file_generation_examples.ny`
- Tests: `tests/test_generator.ny`
