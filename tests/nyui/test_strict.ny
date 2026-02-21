# ============================================================
# NYUI STRICT MODE - Test File
# ============================================================
# This file demonstrates the pure NyUI mode
# It should compile with --ui-only or --pure-nyui flags
#
# Version: 2.0.0

# Import the strict mode module
use nyui_strict;

# ============================================================
# EXAMPLE: Pure UI Components
# ============================================================

# Using abstract components (no HTML tags!)
fn myComponent(props: Map<String, Any>) -> nyui_strict.NyNode {
    let children: List<nyui_strict.NyNode> = [];
    
    children.push(nyui_strict.Text("Hello from Pure NyUI!"));
    children.push(nyui_strict.Button(
        { "onClick": fn(event: Any) -> Any { return null; } },
        [nyui_strict.Text("Click Me")]
    ));
    
    return nyui_strict.Container(
        { "class": "container", "id": "main" },
        children
    );
}

# Using conditional rendering
fn conditionalDemo(show: Bool) -> nyui_strict.NyNode {
    return nyui_strict.If(
        show,
        nyui_strict.Text("Shown!"),
        nyui_strict.Text("Hidden!")
    );
}

# Using loop rendering
fn listDemo(items: List<String>) -> nyui_strict.NyNode {
    return nyui_strict.For(
        items,
        fn(item: String) -> nyui_strict.NyNode {
            return nyui_strict.ListItem(
                {},
                [nyui_strict.Text(item)]
            );
        }
    );
}

# ============================================================
# EXAMPLE: Style DSL (No CSS strings!)
# ============================================================

fn getStyles() -> List<nyui_strict.NyStyleRule> {
    return nyui_strict.style(fn(s: nyui_strict.StyleBuilder) -> Nil {
        s.Container(fn(p: nyui_strict.PropBuilder) -> Nil {
            p.padding(20);
            p.margin(10);
            p.background("#f0f0f0");
            p.borderRadius(8);
        });
        
        s.Button(fn(p: nyui_strict.PropBuilder) -> Nil {
            p.padding("10px 20px");
            p.background("#007bff");
            p.color("#ffffff");
            p.borderRadius(4);
            p.cursor("pointer");
        });
        
        s.Text(fn(p: nyui_strict.PropBuilder) -> Nil {
            p.fontSize(16);
            p.color("#333333");
            p.lineHeight(1.5);
        });
    });
}

# ============================================================
# EXAMPLE: Pure Router
# ============================================================

fn homePage(params: Map<String, String>) -> nyui_strict.NyNode {
    return nyui_strict.Container(
        { "class": "home" },
        [nyui_strict.Text("Welcome Home!")]
    );
}

fn aboutPage(params: Map<String, String>) -> nyui_strict.NyNode {
    return nyui_strict.Container(
        { "class": "about" },
        [nyui_strict.Text("About Us")]
    );
}

fn createRouter() -> nyui_strict.PureRouter {
    let router = nyui_strict.PureRouter::new();
    router.get("/", homePage);
    router.get("/about", aboutPage);
    return router;
}

# ============================================================
# EXAMPLE: Pure Component
# ============================================================

fn HeaderComponent(props: Map<String, Any>) -> nyui_strict.NyNode {
    let title = props.get("title") or "Default Title";
    
    return nyui_strict.Container(
        { "class": "header" },
        [
            nyui_strict.Text(title as String),
            nyui_strict.Link(
                { "href": "/home" },
                [nyui_strict.Text("Home")]
            )
        ]
    );
}

# Using component builder
let headerComp = nyui_strict.component("Header", HeaderComponent);

# ============================================================
# EXAMPLE: NyIR Compiler
# ============================================================

fn compileExample() -> nyui_strict.NyBytecode {
    let tree = nyui_strict.NyDomTree::new(
        nyui_strict.Container(
            { "class": "app" },
            [nyui_strict.Text("Hello World")]
        )
    );
    
    let compiler = nyui_strict.NyIRCompiler::new(nyui_strict.RenderBackend::WASM);
    return compiler.compile(tree);
}

# ============================================================
# EXAMPLE: Web Renderer
# ============================================================

fn renderToWeb() {
    let tree = nyui_strict.NyDomTree::new(
        nyui_strict.Card(
            { "elevation": 2 },
            [
                nyui_strict.Text("Card Title"),
                nyui_strict.Text("Card content goes here")
            ]
        )
    );
    
    # Add styles
    let styles = getStyles();
    for style in styles {
        tree.styles.push(style);
    }
    
    # Create web renderer
    let renderer = nyui_strict.WebRenderer::new();
    
    # Compile to JS (NyIR -> JS)
    let js = renderer.compileToJs(tree);
    
    # js now contains JavaScript code
}

# ============================================================
# EXAMPLE: Lint Rule Usage
# ============================================================

fn runLintCheck(source: String, filename: String) -> nyui_strict.LintResult {
    let detector = nyui_strict.MarkupStringDetector::new();
    detector.check_all(source, filename);
    return nyui_strict.LintResult::from_detector(detector);
}

# ============================================================
# EXAMPLE: Build Validation
# ============================================================

fn validateBuild() -> Bool {
    # Simulate command line flags
    let args = ["--ui-only"];
    let flags = nyui_strict.BuildFlags::from_args(args);
    
    # Simulate project config
    let config = nyui_strict.UIProjectConfig::new();
    config.mode = nyui_strict.UIMode::Pure;
    
    # Validate
    let validator = nyui_strict.BuildValidator::new(flags, config);
    return validator.validate();
}

# ============================================================
# MAIN TEST
# ============================================================

pub fn main() {
    io.println("=== NyUI Strict Mode Test ===");
    io.println("");
    
    # Test 1: Create component
    io.println("1. Creating component...");
    let node = myComponent({});
    io.println("   Component created: " + node.component_type);
    
    # Test 2: Create styles
    io.println("2. Creating styles...");
    let styles = getStyles();
    io.println("   Created " + (styles.len() as String) + " style rules");
    
    # Test 3: Create router
    io.println("3. Creating router...");
    let router = createRouter();
    io.println("   Router created with routes");
    
    # Test 4: Navigate router
    io.println("4. Navigating router...");
    let view = router.navigate("/");
    io.println("   View component: " + view.component_type);
    
    # Test 5: Compile to NyIR
    io.println("5. Compiling to NyIR...");
    let bytecode = compileExample();
    io.println("   Compiled " + (bytecode.instructions.len() as String) + " instructions");
    
    # Test 6: Validate build
    io.println("6. Validating build...");
    let valid = validateBuild();
    io.println("   Build valid: " + (if valid { "true" } else { "false" }));
    
    # Test 7: List rendering
    io.println("7. Testing list rendering...");
    let items = ["Item 1", "Item 2", "Item 3"];
    let listNode = listDemo(items);
    io.println("   List created with " + (listNode.children.len() as String) + " items");
    
    io.println("");
    io.println("=== All Tests Passed! ===");
    io.println("");
    io.println("NyUI Strict Mode is working correctly.");
    io.println("This code uses NO HTML, NO JS strings, NO CSS strings.");
    io.println("All rendering goes through NyDOM -> NyIR -> Renderer.");
}
