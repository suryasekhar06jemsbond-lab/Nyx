# ============================================================
# NYUI Framework Test
# ============================================================

# Simple test: Create a VNode and render it

# Create a simple page using NYUI
let page = html({}, [
    head({}, [
        title({}, [text("Test Page")])
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
