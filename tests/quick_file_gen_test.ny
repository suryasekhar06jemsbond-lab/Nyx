import generator

// Just works - no installation!
generator::generate_txt("hello.txt", "Hello World!");
generator::generate_pdf("report.pdf", "Report", [{type: "heading", text: "Title"}], null);

print("✓ Generated hello.txt");
print("✓ Generated report.pdf");
print("\nFiles created successfully with 100% native Nyx code!");
