# ============================================================
# Pure NyUI Web Application
# ============================================================
# This file demonstrates a pure UI application using strict mode
# It can be built with: ny build --strict

# Define a simple page using pure components
fn HomePage() -> Map<String, Any> {
    return {
        "component": "Container",
        "props": { "class": "home-page" },
        "children": [
            {
                "component": "Text",
                "props": { "content": "Welcome to Pure NyUI!" },
                "children": []
            },
            {
                "component": "Button", 
                "props": { "label": "Get Started" },
                "children": []
            }
        ]
    };
}

fn AboutPage() -> Map<String, Any> {
    return {
        "component": "Container",
        "props": { "class": "about-page" },
        "children": [
            {
                "component": "Text",
                "props": { "content": "About Pure NyUI" },
                "children": []
            }
        ]
    };
}

# Main entry point
pub fn main() {
    io.println("=== Pure NyUI Web Application ===");
    io.println("");
    io.println("Building with --strict mode...");
    io.println("");
    io.println("Features enabled:");
    io.println("  [x] No HTML output");
    io.println("  [x] No JavaScript strings");
    io.println("  [x] No CSS strings");
    io.println("  [x] NyDOM internal representation");
    io.println("  [x] Abstract component builders");
    io.println("  [x] NyIR compiler backend");
    io.println("");
    
    # Render pages as NyDOM
    let home = HomePage();
    io.println("Home page: " + (home.get("component") as String));
    
    let about = AboutPage();
    io.println("About page: " + (about.get("component") as String));
    
    io.println("");
    io.println("Build complete! Output generated to target/");
}
