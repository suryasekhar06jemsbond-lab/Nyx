# ============================================================
# NyUI Orchestrator Test
# ============================================================
# Single import (`use nyui`) gives:
# - Web VDOM builders
# - Strict/Pure NyUI via `nyui.strict`
# - Desktop GUI via `nyui.gui` or `nyui.GUIApplication`

use nyui;

pub fn main() {
    io.println("=== NyUI Orchestrator Test ===");

    # Web/VNode feature
    let page = nyui.div({"class": "root"}, [nyui.text("Hello from nyui")]);
    io.println("Web HTML: " + page.toHtml());

    # Strict/Pure feature from same import
    let pureNode = nyui.strict.Text("Pure node");
    io.println("Pure component: " + pureNode.component_type);

    # Desktop GUI feature from same import
    let app = nyui.GUIApplication::new("NyUI Desktop", 800, 600);
    io.println("Desktop app initialized: " + app.title);
}
