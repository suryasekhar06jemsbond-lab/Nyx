# ============================================================
# NYUI Framework Test - Simple
# ============================================================

# Simple test using basic elements

# Create a simple page using NYUI
let page = html({}, [
    head({}, [
        meta({"charset": "UTF-8"})
    ]),
    body({}, [
        div({"class": "container"}, [
            h1({}, [text("Hello from NYUI!")]),
            p({}, [text("This is rendered using the native UI framework.")])
        ])
    ])
]);

# Render to HTML
io.println("=== NYUI VNode Test ===");
io.println("");
io.println(page.toHtml());
io.println("");
io.println("=== Test Complete ===");
