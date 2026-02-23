# ===========================================
# Nyx File Generator Tests
# ===========================================
# Test suite for file generation module

import generator
import io
import test

fn test_txt_generation() {
    """Test plain text file generation"""
    let path = "/tmp/test_nyx_gen.txt";
    let content = "Test content\nLine 2\nLine 3";
    
    generator::generate_txt(path, content);
    
    let read_content = io::read_file(path);
    test::assert_equal(read_content, content, "TXT content matches");
    
    # Cleanup
    try {
        io::delete_file(path);
    } catch e {
        # Ignore
    }
    
    return true;
}

fn test_md_generation() {
    """Test Markdown file generation"""
    let path = "/tmp/test_nyx_gen.md";
    let sections = [
        {heading: "Section 1", content: "Content 1", level: 2},
        {heading: "Section 2", content: "Content 2", level: 3}
    ];
    
    generator::generate_md(path, "Test Document", sections);
    
    let content = io::read_file(path);
    test::assert_true(contains(content, "# Test Document"), "MD has title");
    test::assert_true(contains(content, "## Section 1"), "MD has section 1");
    test::assert_true(contains(content, "### Section 2"), "MD has section 2");
    
    # Cleanup
    try {
        io::delete_file(path);
    } catch e {
        # Ignore
    }
    
    return true;
}

fn test_csv_generation() {
    """Test CSV file generation"""
    let path = "/tmp/test_nyx_gen.csv";
    let headers = ["Name", "Age", "City"];
    let rows = [
        ["Alice", "30", "NYC"],
        ["Bob", "25", "LA"]
    ];
    
    generator::generate_csv(path, headers, rows, ",");
    
    let content = io::read_file(path);
    let lines = split(content, "\n");
    
    test::assert_true(contains(lines[0], "Name"), "CSV has headers");
    test::assert_true(contains(lines[1], "Alice"), "CSV has data row 1");
    test::assert_true(contains(lines[2], "Bob"), "CSV has data row 2");
    
    # Cleanup
    try {
        io::delete_file(path);
    } catch e {
        # Ignore
    }
    
    return true;
}

fn test_csv_with_escaping() {
    """Test CSV generation with special characters"""
    let path = "/tmp/test_nyx_csv_escape.csv";
    let headers = ["Name", "Description"];
    let rows = [
        ["Item 1", "Contains, comma"],
        ["Item 2", "Contains \"quotes\""]
    ];
    
    generator::generate_csv(path, headers, rows, ",");
    
    let content = io::read_file(path);
    test::assert_true(contains(content, "\"Contains, comma\""), "CSV escapes comma");
    test::assert_true(contains(content, "\"\""), "CSV escapes quotes");
    
    # Cleanup
    try {
        io::delete_file(path);
    } catch e {
        # Ignore
    }
    
    return true;
}

fn test_rtf_generation() {
    """Test RTF file generation"""
    let path = "/tmp/test_nyx_gen.rtf";
    
    generator::generate_rtf(path, "Test RTF", "This is test content.", 24);
    
    let content = io::read_file(path);
    test::assert_true(contains(content, "{\\rtf1"), "RTF has header");
    test::assert_true(contains(content, "Test RTF"), "RTF has title");
    test::assert_true(contains(content, "test content"), "RTF has content");
    
    # Cleanup
    try {
        io::delete_file(path);
    } catch e {
        # Ignore
    }
    
    return true;
}

fn test_svg_generation() {
    """Test SVG file generation"""
    let path = "/tmp/test_nyx_gen.svg";
    let elements = [
        {type: "rect", x: 10, y: 10, width: 100, height: 50, fill: "blue"},
        {type: "circle", cx: 150, cy: 75, r: 30, fill: "red"},
        {type: "text", x: 50, y: 100, content: "Test", fill: "black"}
    ];
    
    generator::generate_svg(path, 300, 200, elements);
    
    let content = io::read_file(path);
    test::assert_true(contains(content, "<?xml"), "SVG has XML header");
    test::assert_true(contains(content, "<svg"), "SVG has svg tag");
    test::assert_true(contains(content, "<rect"), "SVG has rect");
    test::assert_true(contains(content, "<circle"), "SVG has circle");
    test::assert_true(contains(content, "<text"), "SVG has text");
    test::assert_true(contains(content, "Test"), "SVG has text content");
    
    # Cleanup
    try {
        io::delete_file(path);
    } catch e {
        # Ignore
    }
    
    return true;
}

fn test_svg_shapes() {
    """Test various SVG shapes"""
    let path = "/tmp/test_nyx_svg_shapes.svg";
    let elements = [
        {type: "line", x1: 0, y1: 0, x2: 100, y2: 100, stroke: "black", stroke_width: 2},
        {type: "path", d: "M 10 10 L 50 50 L 90 10 Z", fill: "green", stroke: "blue"}
    ];
    
    generator::generate_svg(path, 200, 150, elements);
    
    let content = io::read_file(path);
    test::assert_true(contains(content, "<line"), "SVG has line");
    test::assert_true(contains(content, "<path"), "SVG has path");
    
    # Cleanup
    try {
        io::delete_file(path);
    } catch e {
        # Ignore
    }
    
    return true;
}

fn test_format_detection() {
    """Test automatic format detection from extension"""
    let format1 = generator::detect_format("test.txt");
    test::assert_equal(format1, "txt", "Detects TXT format");
    
    let format2 = generator::detect_format("document.PDF");
    test::assert_equal(format2, "pdf", "Detects PDF format (case insensitive)");
    
    let format3 = generator::detect_format("data.csv");
    test::assert_equal(format3, "csv", "Detects CSV format");
    
    return true;
}

fn test_unified_interface_txt() {
    """Test unified interface with TXT format"""
    let path = "/tmp/test_unified.txt";
    
    generator::generate_file(path, "txt", "Unified interface test");
    
    let content = io::read_file(path);
    test::assert_equal(content, "Unified interface test", "Unified TXT generation works");
    
    # Cleanup
    try {
        io::delete_file(path);
    } catch e {
        # Ignore
    }
    
    return true;
}

fn test_unified_interface_md() {
    """Test unified interface with MD format"""
    let path = "/tmp/test_unified.md";
    let data = {
        title: "Test",
        sections: [{heading: "H1", content: "C1", level: 2}]
    };
    
    generator::generate_file(path, "md", data);
    
    let content = io::read_file(path);
    test::assert_true(contains(content, "# Test"), "Unified MD generation works");
    
    # Cleanup
    try {
        io::delete_file(path);
    } catch e {
        # Ignore
    }
    
    return true;
}

fn test_template_generation() {
    """Test template-based file generation"""
    let template_path = "/tmp/test_template.txt";
    let output_path = "/tmp/test_from_template.txt";
    
    # Create template
    let template = "Name: {{name}}\nAge: {{age}}\nCity: {{city}}";
    io::write_file(template_path, template);
    
    # Generate from template
    let vars = {
        name: "Alice",
        age: "30",
        city: "NYC"
    };
    generator::generate_from_template(template_path, output_path, vars);
    
    # Verify
    let content = io::read_file(output_path);
    test::assert_true(contains(content, "Name: Alice"), "Template has name");
    test::assert_true(contains(content, "Age: 30"), "Template has age");
    test::assert_true(contains(content, "City: NYC"), "Template has city");
    test::assert_false(contains(content, "{{"), "Template variables replaced");
    
    # Cleanup
    try {
        io::delete_file(template_path);
        io::delete_file(output_path);
    } catch e {
        # Ignore
    }
    
    return true;
}

fn test_batch_generation() {
    """Test batch file generation"""
    let specs = [
        {
            path: "/tmp/batch1.txt",
            format: "txt",
            data: "Batch file 1"
        },
        {
            path: "/tmp/batch2.txt",
            format: "txt",
            data: "Batch file 2"
        }
    ];
    
    let results = generator::generate_files(specs);
    
    test::assert_equal(len(results), 2, "Batch generates correct count");
    
    let content1 = io::read_file("/tmp/batch1.txt");
    let content2 = io::read_file("/tmp/batch2.txt");
    
    test::assert_equal(content1, "Batch file 1", "Batch file 1 correct");
    test::assert_equal(content2, "Batch file 2", "Batch file 2 correct");
    
    # Cleanup
    try {
        io::delete_file("/tmp/batch1.txt");
        io::delete_file("/tmp/batch2.txt");
    } catch e {
        # Ignore
    }
    
    return true;
}

fn test_escape_rtf() {
    """Test RTF escaping"""
    let text = "Test {braces} and \\backslash";
    let escaped = generator::escape_rtf(text);
    
    test::assert_true(contains(escaped, "\\{"), "Escapes left brace");
    test::assert_true(contains(escaped, "\\}"), "Escapes right brace");
    test::assert_true(contains(escaped, "\\\\"), "Escapes backslash");
    
    return true;
}

fn test_escape_path() {
    """Test path escaping"""
    let path = "C:\\Users\\Test\\file.txt";
    let escaped = generator::escape_path(path);
    
    test::assert_true(contains(escaped, "\\\\"), "Escapes backslashes in path");
    
    return true;
}

# ===========================================
# RUN ALL TESTS
# ===========================================

fn run_all_tests() {
    print("Running Nyx File Generator Tests");
    print("=================================\n");
    
    let tests = [
        {name: "TXT Generation", fn: test_txt_generation},
        {name: "MD Generation", fn: test_md_generation},
        {name: "CSV Generation", fn: test_csv_generation},
        {name: "CSV Escaping", fn: test_csv_with_escaping},
        {name: "RTF Generation", fn: test_rtf_generation},
        {name: "SVG Generation", fn: test_svg_generation},
        {name: "SVG Shapes", fn: test_svg_shapes},
        {name: "Format Detection", fn: test_format_detection},
        {name: "Unified Interface (TXT)", fn: test_unified_interface_txt},
        {name: "Unified Interface (MD)", fn: test_unified_interface_md},
        {name: "Template Generation", fn: test_template_generation},
        {name: "Batch Generation", fn: test_batch_generation},
        {name: "RTF Escaping", fn: test_escape_rtf},
        {name: "Path Escaping", fn: test_escape_path}
    ];
    
    let passed = 0;
    let failed = 0;
    
    for test_case in tests {
        try {
            let result = test_case.fn();
            if result {
                print("✓ " + test_case.name);
                passed = passed + 1;
            } else {
                print("✗ " + test_case.name + " (returned false)");
                failed = failed + 1;
            }
        } catch e {
            print("✗ " + test_case.name + " (error: " + str(e) + ")");
            failed = failed + 1;
        }
    }
    
    print("\n=================================");
    print("Results: " + str(passed) + " passed, " + str(failed) + " failed");
    print("=================================");
    
    if failed == 0 {
        print("\n✓ All tests passed!");
        return 0;
    } else {
        print("\n✗ Some tests failed!");
        return 1;
    }
}

# Run tests
run_all_tests();
