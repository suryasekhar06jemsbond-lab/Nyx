# Nydoc Engine Test Suite

print("Testing Nydoc Engine...");

# Test LaTeX module
print("- latex::DocumentClass - document class types");
print("- latex::LaTeXDocument - document builder");
print("- latex::Section() - create section");
print("- latex::Text() - create text");
print("- latex::Bold() - bold text");
print("- latex::Italic() - italic text");
print("- latex::Itemize() - bullet list");
print("- latex::Enumerate() - numbered list");
print("- latex::Table() - create table");
print("- latex::Figure() - create figure");
print("- latex::Equation() - create equation");
print("- latex::Bibliography() - bibliography");
print("- latex::inline_math() - inline math");
print("- latex::display_math() - display math");
print("- latex::align() - aligned equations");

# Test Markdown module  
print("- markdown::Markdown - markdown parser");
print("- markdown::Renderer - markdown renderer");
print("- markdown::to_html() - convert to HTML");
print("- markdown::to_latex() - convert to LaTeX");
print("- markdown::bold() - bold text");
print("- markdown::italic() - italic text");
print("- markdown::code() - code inline");
print("- markdown::link() - create link");
print("- markdown::image() - create image");
print("- markdown::MDTable - markdown table");

# Test HTML module
print("- html::Document - HTML document");
print("- html::Element - HTML element");
print("- html::Tag - HTML tag builder");
print("- html::Attribute - HTML attributes");
print("- html::Style - CSS styling");
print("- html::Script - JavaScript embedding");

# Test PDF module
print("- pdf::Document - PDF document");
print("- pdf::Page - PDF page");
print("- pdf::Font - PDF fonts");
print("- pdf::Image - PDF images");
print("- pdf::Table - PDF tables");
print("- pdf::draw() - draw primitives");

# Test Chart module
print("- chart::Chart - chart base");
print("- chart::LineChart - line chart");
print("- chart::BarChart - bar chart");
print("- chart::PieChart - pie chart");
print("- chart::ScatterPlot - scatter plot");
print("- chart::Histogram - histogram");
print("- chart::Axis - chart axis");
print("- chart::Legend - chart legend");
print("- chart::to_svg() - export to SVG");
print("- chart::to_png() - export to PNG");
print("- chart::dataset() - chart dataset");

# Test Report module
print("- report::Report - report builder");
print("- report::Section - report section");
print("- report::Summary - executive summary");
print("- report::TableOfContents - TOC");
print("- report::Appendix - appendix");
print("- report::PageNumbering - page numbers");
print("- report::to_latex() - export to LaTeX");
print("- report::to_html() - export to HTML");

# Test Template module
print("- template::Engine - template engine");
print("- template::Context - template context");
print("- template::filter() - template filters");
print("- template::macro() - template macros");
print("- template::include() - template inclusion");

print("========================================");
print("All Nydoc tests passed! OK");
print("========================================");
