# Quick test to verify file generation capabilities
import generator

print("Testing Nyx File Generation...\n");

# Test 1: Plain Text
print("1. Testing TXT generation...");
generator::generate_txt("test_output.txt", "Hello from Nyx!\nThis is a test file.");
print("   ✓ Generated test_output.txt\n");

# Test 2: Markdown
print("2. Testing Markdown generation...");
let sections = [
    {heading: "Overview", content: "Nyx can generate Markdown files.", level: 2},
    {heading: "Features", content: "- Easy\n- Fast\n- Powerful", level: 2}
];
generator::generate_md("test_output.md", "Nyx Test Document", sections);
print("   ✓ Generated test_output.md\n");

# Test 3: CSV
print("3. Testing CSV generation...");
let headers = ["ID", "Name", "Status"];
let rows = [
    ["1", "Item A", "Active"],
    ["2", "Item B", "Pending"],
    ["3", "Item C", "Complete"]
];
generator::generate_csv("test_output.csv", headers, rows, ",");
print("   ✓ Generated test_output.csv\n");

# Test 4: SVG
print("4. Testing SVG generation...");
let elements = [
    {type: "rect", x: 0, y: 0, width: 200, height: 100, fill: "lightblue"},
    {type: "circle", cx: 100, cy: 50, r: 30, fill: "yellow"},
    {type: "text", x: 100, y: 55, content: "Nyx", fill: "blue", font_size: 20}
];
generator::generate_svg("test_output.svg", 200, 100, elements);
print("   ✓ Generated test_output.svg\n");

print("✅ All basic tests passed!");
print("\nGenerated files:");
print("  - test_output.txt");
print("  - test_output.md");
print("  - test_output.csv");
print("  - test_output.svg");
print("\nFor PNG/JPG/PDF/DOCX/XLSX/PPTX support, install Python libraries:");
print("  pip install -r requirements_file_generation.txt");
