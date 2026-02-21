# ============================================================
# NYUI STRICT MODE - Pure UI Framework
# ============================================================
# A strict, HTML-free UI framework that:
# - Uses NyDOM internal representation
# - Supports multiple renderer backends
# - Enforces pure mode at compile time
# - Rejects HTML, JS, CSS strings
#
# Version: 2.0.0

let NYUI_STRICT_VERSION = "2.0.0";

# ============================================================
# PURE MODE CONFIGURATION
# ============================================================

pub mod config {
    # UI Mode types
    pub enum UIMode {
        Standard,   # Normal mode with HTML support
        Pure        # Strict mode - no HTML, JS, CSS
    }
    
    # Feature flags for pure mode
    pub class PureModeConfig {
        pub let allow_html: Bool;
        pub let allow_js: Bool;
        pub let allow_css: Bool;
        pub let allow_markup_strings: Bool;
        pub let allow_script_tags: Bool;
        pub let allow_style_tags: Bool;
        
        pub fn new() -> Self {
            return Self {
                allow_html: false,
                allow_js: false,
                allow_css: false,
                allow_markup_strings: false,
                allow_script_tags: false,
                allow_style_tags: false
            };
        }
        
        # Strictest possible config
        pub fn maximum() -> Self {
            let config = Self::new();
            return config;
        }
    }
    
    # Project UI configuration
    pub class UIProjectConfig {
        pub let mode: UIMode;
        pub let pure: PureModeConfig;
        pub let renderer: String;  # "web", "desktop", "mobile", "wasm"
        
        pub fn new() -> Self {
            return Self {
                mode: UIMode::Standard,
                pure: PureModeConfig::new(),
                renderer: "web"
            };
        }
        
        pub fn pure() -> Self {
            let config = Self::new();
            config.mode = UIMode::Pure;
            return config;
        }
        
        pub fn is_pure(self) -> Bool {
            return self.mode == UIMode::Pure;
        }
    }
    
    # Parse from nyx.toml format
    pub fn parse_toml_config(table: Map<String, Any>) -> UIProjectConfig {
        let config = UIProjectConfig::new();
        
        if table.has("mode") {
            let mode_str = table.get("mode") as String;
            if mode_str == "pure" {
                config.mode = UIMode::Pure;
            }
        }
        
        if table.has("renderer") {
            config.renderer = table.get("renderer") as String;
        }
        
        if table.has("allow_html") {
            config.pure.allow_html = table.get("allow_html") as Bool;
        }
        
        if table.has("allow_js") {
            config.pure.allow_js = table.get("allow_js") as Bool;
        }
        
        if table.has("allow_css") {
            config.pure.allow_css = table.get("allow_css") as Bool;
        }
        
        return config;
    }
}

# ============================================================
# NYDOM - Internal DOM Representation
# ============================================================
# Instead of HTML strings, we use an intermediate representation

pub mod nydom {
    # NyDOM Node types - abstract, no HTML references
    pub enum NyNodeType {
        Element,
        Text,
        Component,
        Fragment,
        Portal
    }
    
    # NyDOM Node - the core internal representation
    pub class NyNode {
        pub let node_type: NyNodeType;
        pub let component_type: String;  # Abstract component name
        pub let props: Map<String, Any>;
        pub let children: List<NyNode>;
        pub let events: Map<String, fn(Any) -> Any>;
        pub let key: String;
        pub let ref: Any;
        
        pub fn new(component_type: String) -> Self {
            return Self {
                node_type: NyNodeType::Element,
                component_type: component_type,
                props: {},
                children: [],
                events: {},
                key: "",
                ref: null
            };
        }
        
        # Create text node
        pub fn text(content: String) -> Self {
            return Self {
                node_type: NyNodeType::Text,
                component_type: "Text",
                props: { "content": content },
                children: [],
                events: {},
                key: "",
                ref: null
            };
        }
        
        # Create fragment (multiple children)
        pub fn fragment(children: List<NyNode>) -> Self {
            return Self {
                node_type: NyNodeType::Fragment,
                component_type: "Fragment",
                props: {},
                children: children,
                events: {},
                key: "",
                ref: null
            };
        }
        
        # Set prop
        pub fn prop(self, key: String, value: Any) -> Self {
            self.props.set(key, value);
            return self;
        }
        
        # Set multiple props
        pub fn props(self, props: Map<String, Any>) -> Self {
            for k, v in props {
                self.props.set(k, v);
            }
            return self;
        }
        
        # Add child
        pub fn child(self, child: NyNode) -> Self {
            self.children.push(child);
            return self;
        }
        
        # Add multiple children
        pub fn children(self, children: List<NyNode>) -> Self {
            for c in children {
                self.children.push(c);
            }
            return self;
        }
        
        # Add event handler
        pub fn on(self, event: String, handler: fn(Any) -> Any) -> Self {
            self.events.set(event, handler);
            return self;
        }
        
        # Set key
        pub fn key(self, key: String) -> Self {
            self.key = key;
            return self;
        }
        
        # Set ref
        pub fn ref(self, ref: Any) -> Self {
            self.ref = ref;
            return self;
        }
    }
    
    # NyDOM Tree - complete tree structure
    pub class NyDomTree {
        pub let root: NyNode;
        pub let styles: List<NyStyleRule>;
        
        pub fn new(root: NyNode) -> Self {
            return Self {
                root: root,
                styles: []
            };
        }
        
        # Add style rule
        pub fn style(self, rule: NyStyleRule) -> Self {
            self.styles.push(rule);
            return self;
        }
    }
    
    # Style rule (abstracted from CSS)
    pub class NyStyleRule {
        pub let selector: String;
        pub let properties: Map<String, Any>;
        
        pub fn new(selector: String) -> Self {
            return Self {
                selector: selector,
                properties: {}
            };
        }
        
        pub fn set(self, key: String, value: Any) -> Self {
            self.properties.set(key, value);
            return self;
        }
    }
    
    # NyBytecode - compiled intermediate representation
    pub class NyBytecode {
        pub let instructions: List<NyInstruction>;
        pub let constants: List<Any>;
        
        pub fn new() -> Self {
            return Self {
                instructions: [],
                constants: []
            };
        }
        
        pub fn add(self, instr: NyInstruction) -> Self {
            self.instructions.push(instr);
            return self;
        }
    }
    
    # NyIR Instructions
    pub enum NyInstruction {
        CreateElement { component: String, props: Map<String, Any> },
        CreateText { content: String },
        CreateFragment { count: Int },
        AddChild,
        SetProp { key: String, value: Any },
        SetEvent { event: String, handler_id: Int },
        SetKey { key: String },
        Mount { container: String },
        Update { path: String },
        Remove { path: String }
    }
}

# ============================================================
# NYRENDERER - Backend Abstraction
# ============================================================

pub mod renderer {
    # Renderer backend types
    pub enum RenderBackend {
        Web,       # Browser DOM
        Desktop,   # Native desktop (GTK, Qt, etc.)
        Mobile,   # Mobile (iOS, Android)
        WASM,      # WebAssembly
        Console   # Terminal/CLI
    }
    
    # Renderer trait - all backends implement this
    pub class NyRenderer {
        pub let backend: RenderBackend;
        
        pub fn new(backend: RenderBackend) -> Self {
            return Self {
                backend: backend
            };
        }
        
        # Render NyDOM to target
        pub fn render(self, tree: nydom.NyDomTree) -> Any {
            match self.backend {
                RenderBackend::Web => return self._render_web(tree),
                RenderBackend::Desktop => return self._render_desktop(tree),
                RenderBackend::Mobile => return self._render_mobile(tree),
                RenderBackend::WASM => return self._render_wasm(tree),
                RenderBackend::Console => return self._render_console(tree)
            }
        }
        
        # Render to NyBytecode
        pub fn compile(self, tree: nydom.NyDomTree) -> nydom.NyBytecode {
            return self._compile_ir(tree);
        }
        
        # Abstract methods to be implemented by backends
        fn _render_web(self, tree: nydom.NyDomTree) -> Any { return null; }
        fn _render_desktop(self, tree: nydom.NyDomTree) -> Any { return null; }
        fn _render_mobile(self, tree: nydom.NyDomTree) -> Any { return null; }
        fn _render_wasm(self, tree: nydom.NyDomTree) -> Any { return null; }
        fn _render_console(self, tree: nydom.NyDomTree) -> Any { return null; }
        
        fn _compile_ir(self, tree: nydom.NyDomTree) -> nydom.NyBytecode {
            let bc = nydom.NyBytecode::new();
            self._compile_node(tree.root, bc);
            return bc;
        }
        
        fn _compile_node(self, node: nydom.NyNode, bc: nydom.NyBytecode) {
            match node.node_type {
                nydom.NyNodeType::Text => {
                    bc.add(nydom.NyInstruction::CreateText { 
                        content: node.props.get("content") as String 
                    });
                },
                nydom.NyNodeType::Fragment => {
                    bc.add(nydom.NyInstruction::CreateFragment { 
                        count: node.children.len() 
                    });
                    for child in node.children {
                        self._compile_node(child, bc);
                    }
                },
                _ => {
                    bc.add(nydom.NyInstruction::CreateElement { 
                        component: node.component_type, 
                        props: node.props 
                    });
                    for child in node.children {
                        self._compile_node(child, bc);
                        bc.add(nydom.NyInstruction::AddChild);
                    }
                }
            }
        }
    }
    
    # Web Renderer - compiles to browser-compatible format
    pub class WebRenderer {
        pub let super: NyRenderer;
        
        pub fn new() -> Self {
            return Self {
                super: NyRenderer::new(RenderBackend::Web)
            };
        }
        
        # Compile to JavaScript (not direct JS, but NyIR that becomes JS)
        pub fn compileToJs(self, tree: nydom.NyDomTree) -> String {
            # This compiles to NyBytecode, which can then be transpiled to JS
            let bc = self.super.compile(tree);
            return self._bytecode_to_js(bc);
        }
        
        fn _bytecode_to_js(self, bc: nydom.NyBytecode) -> String {
            let js = "function render() { return ";
            # Simplified - real impl would translate each instruction
            js = js + "nyx.createElement('div', {}, []);";
            js = js + " }";
            return js;
        }
    }
}

# ============================================================
# UI COMPONENT BUILDERS - Abstract Components
# ============================================================
# These replace HTML tags with abstract component names

pub mod ui {
    use nydom::*;
    
    # Container - generic container (replaces div)
    pub fn Container(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Container").props(props).children(children);
    }
    
    # Text - text content (replaces raw text)
    pub fn Text(content: String) -> NyNode {
        return NyNode::text(content);
    }
    
    # Button - interactive button
    pub fn Button(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Button").props(props).children(children);
    }
    
    # Input - form input
    pub fn Input(props: Map<String, Any>) -> NyNode {
        return NyNode::new("Input").props(props);
    }
    
    # List - list container
    pub fn List(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("List").props(props).children(children);
    }
    
    # ListItem - list item
    pub fn ListItem(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("ListItem").props(props).children(children);
    }
    
    # Image - image element
    pub fn Image(props: Map<String, Any>) -> NyNode {
        return NyNode::new("Image").props(props);
    }
    
    # Link - navigation link
    pub fn Link(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Link").props(props).children(children);
    }
    
    # Form - form container
    pub fn Form(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Form").props(props).children(children);
    }
    
    # Card - card container
    pub fn Card(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Card").props(props).children(children);
    }
    
    # Grid - grid layout
    pub fn Grid(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Grid").props(props).children(children);
    }
    
    # Flex - flex layout
    pub fn Flex(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Flex").props(props).children(children);
    }
    
    # Stack - vertical stack
    pub fn Stack(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Stack").props(props).children(children);
    }
    
    # Spacer - spacing element
    pub fn Spacer(props: Map<String, Any>) -> NyNode {
        return NyNode::new("Spacer").props(props);
    }
    
    # Icon - icon element
    pub fn Icon(props: Map<String, Any>) -> NyNode {
        return NyNode::new("Icon").props(props);
    }
    
    # Avatar - avatar element
    pub fn Avatar(props: Map<String, Any>) -> NyNode {
        return NyNode::new("Avatar").props(props);
    }
    
    # Badge - badge element
    pub fn Badge(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Badge").props(props).children(children);
    }
    
    # Modal - modal dialog
    pub fn Modal(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Modal").props(props).children(children);
    }
    
    # Drawer - side drawer
    pub fn Drawer(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Drawer").props(props).children(children);
    }
    
    # Toolbar - toolbar
    pub fn Toolbar(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Toolbar").props(props).children(children);
    }
    
    # Menu - menu container
    pub fn Menu(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Menu").props(props).children(children);
    }
    
    # MenuItem - menu item
    pub fn MenuItem(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("MenuItem").props(props).children(children);
    }
    
    # Table - table container
    pub fn Table(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Table").props(props).children(children);
    }
    
    # TableRow - table row
    pub fn TableRow(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("TableRow").props(props).children(children);
    }
    
    # TableCell - table cell
    pub fn TableCell(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("TableCell").props(props).children(children);
    }
    
    # Tabs - tab container
    pub fn Tabs(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Tabs").props(props).children(children);
    }
    
    # Tab - tab panel
    pub fn Tab(props: Map<String, Any>, children: List<NyNode>) -> NyNode {
        return NyNode::new("Tab").props(props).children(children);
    }
    
    # Fragment - multiple children without wrapper
    pub fn Fragment(children: List<NyNode>) -> NyNode {
        return NyNode::fragment(children);
    }
    
    # Conditional - conditional rendering
    pub fn If(condition: Bool, then: NyNode, else_node: NyNode) -> NyNode {
        if condition {
            return then;
        }
        return else_node;
    }
    
    # Loop - list rendering
    pub fn For<T>(items: List<T>, render: fn(T) -> NyNode) -> NyNode {
        let children: List<NyNode> = [];
        for item in items {
            children.push(render(item));
        }
        return NyNode::fragment(children);
    }
}

# ============================================================
# STYLE SYSTEM - No CSS strings
# ============================================================

pub mod styles {
    use nydom::*;
    
    # Style block - DSL for styles (not CSS strings)
    pub fn style(rules: fn(StyleBuilder) -> Nil) -> List<NyStyleRule> {
        let builder = StyleBuilder::new();
        rules(builder);
        return builder.rules;
    }
    
    # Style builder DSL
    pub class StyleBuilder {
        pub let rules: List<NyStyleRule>;
        
        pub fn new() -> Self {
            return Self {
                rules: []
            };
        }
        
        # Define component styles
        pub fn Container(self, props: fn(PropBuilder) -> Nil) -> Self {
            let rule = NyStyleRule::new("Container");
            let pb = PropBuilder::new(rule);
            props(pb);
            self.rules.push(rule);
            return self;
        }
        
        pub fn Button(self, props: fn(PropBuilder) -> Nil) -> Self {
            let rule = NyStyleRule::new("Button");
            let pb = PropBuilder::new(rule);
            props(pb);
            self.rules.push(rule);
            return self;
        }
        
        pub fn Text(self, props: fn(PropBuilder) -> Nil) -> Self {
            let rule = NyStyleRule::new("Text");
            let pb = PropBuilder::new(rule);
            props(pb);
            self.rules.push(rule);
            return self;
        }
        
        pub fn Input(self, props: fn(PropBuilder) -> Nil) -> Self {
            let rule = NyStyleRule::new("Input");
            let pb = PropBuilder::new(rule);
            props(pb);
            self.rules.push(rule);
            return self;
        }
        
        # Custom selector
        pub fn selector(self, name: String, props: fn(PropBuilder) -> Nil) -> Self {
            let rule = NyStyleRule::new(name);
            let pb = PropBuilder::new(rule);
            props(pb);
            self.rules.push(rule);
            return self;
        }
    }
    
    # Property builder for styles
    pub class PropBuilder {
        let rule: NyStyleRule;
        
        pub fn new(rule: NyStyleRule) -> Self {
            return Self { rule: rule };
        }
        
        pub fn padding(self, value: Any) -> Self {
            self.rule.properties.set("padding", value);
            return self;
        }
        
        pub fn margin(self, value: Any) -> Self {
            self.rule.properties.set("margin", value);
            return self;
        }
        
        pub fn width(self, value: Any) -> Self {
            self.rule.properties.set("width", value);
            return self;
        }
        
        pub fn height(self, value: Any) -> Self {
            self.rule.properties.set("height", value);
            return self;
        }
        
        pub fn color(self, value: Any) -> Self {
            self.rule.properties.set("color", value);
            return self;
        }
        
        pub fn background(self, value: Any) -> Self {
            self.rule.properties.set("background", value);
            return self;
        }
        
        pub fn fontSize(self, value: Any) -> Self {
            self.rule.properties.set("fontSize", value);
            return self;
        }
        
        pub fn fontWeight(self, value: Any) -> Self {
            self.rule.properties.set("fontWeight", value);
            return self;
        }
        
        pub fn border(self, value: Any) -> Self {
            self.rule.properties.set("border", value);
            return self;
        }
        
        pub fn borderRadius(self, value: Any) -> Self {
            self.rule.properties.set("borderRadius", value);
            return self;
        }
        
        pub fn display(self, value: Any) -> Self {
            self.rule.properties.set("display", value);
            return self;
        }
        
        pub fn flexDirection(self, value: Any) -> Self {
            self.rule.properties.set("flexDirection", value);
            return self;
        }
        
        pub fn justifyContent(self, value: Any) -> Self {
            self.rule.properties.set("justifyContent", value);
            return self;
        }
        
        pub fn alignItems(self, value: Any) -> Self {
            self.rule.properties.set("alignItems", value);
            return self;
        }
        
        pub fn gap(self, value: Any) -> Self {
            self.rule.properties.set("gap", value);
            return self;
        }
        
        pub fn opacity(self, value: Any) -> Self {
            self.rule.properties.set("opacity", value);
            return self;
        }
        
        pub fn position(self, value: Any) -> Self {
            self.rule.properties.set("position", value);
            return self;
        }
        
        pub fn top(self, value: Any) -> Self {
            self.rule.properties.set("top", value);
            return self;
        }
        
        pub fn left(self, value: Any) -> Self {
            self.rule.properties.set("left", value);
            return self;
        }
        
        pub fn right(self, value: Any) -> Self {
            self.rule.properties.set("right", value);
            return self;
        }
        
        pub fn bottom(self, value: Any) -> Self {
            self.rule.properties.set("bottom", value);
            return self;
        }
        
        pub fn zIndex(self, value: Any) -> Self {
            self.rule.properties.set("zIndex", value);
            return self;
        }
        
        pub fn cursor(self, value: Any) -> Self {
            self.rule.properties.set("cursor", value);
            return self;
        }
        
        pub fn overflow(self, value: Any) -> Self {
            self.rule.properties.set("overflow", value);
            return self;
        }
        
        pub fn textAlign(self, value: Any) -> Self {
            self.rule.properties.set("textAlign", value);
            return self;
        }
        
        pub fn lineHeight(self, value: Any) -> Self {
            self.rule.properties.set("lineHeight", value);
            return self;
        }
        
        pub fn letterSpacing(self, value: Any) -> Self {
            self.rule.properties.set("letterSpacing", value);
            return self;
        }
        
        pub fn textTransform(self, value: Any) -> Self {
            self.rule.properties.set("textTransform", value);
            return self;
        }
        
        pub fn whiteSpace(self, value: Any) -> Self {
            self.rule.properties.set("whiteSpace", value);
            return self;
        }
        
        pub fn wordBreak(self, value: Any) -> Self {
            self.rule.properties.set("wordBreak", value);
            return self;
        }
        
        # Custom property
        pub fn custom(self, key: String, value: Any) -> Self {
            self.rule.properties.set(key, value);
            return self;
        }
    }
}

# ============================================================
# LINT RULES - Markup String Detection
# ============================================================

pub mod lint {
    # Lint rule for detecting raw markup strings
    pub class MarkupStringDetector {
        pub let violations: List<LintViolation>;
        
        pub fn new() -> Self {
            return Self {
                violations: []
            };
        }
        
        # Check source code for markup strings
        pub fn check_source(self, source: String, file: String) -> Self {
            # Pattern to match strings containing HTML-like markup
            # Matches: "<div>", "<span>", "<p>", etc.
            let pattern = "\"[^\"]*<[a-zA-Z][a-zA-Z0-9]*[^\"]*\"";
            
            # Split source into lines for reporting
            let lines = source.split("\n");
            for i in range(lines.len()) {
                let line = lines[i];
                # Check if line contains markup-like string
                if self._contains_markup(line) {
                    self.violations.push(LintViolation {
                        file: file,
                        line: i + 1,
                        column: 0,
                        message: "Raw markup not allowed in pure NyUI mode: " + self._extract_markup(line),
                        severity: "error",
                        code: "NYUI001"
                    });
                }
            }
            
            return self;
        }
        
        fn _contains_markup(self, line: String) -> Bool {
            # Simple heuristic: contains < and > with something between
            if !line.contains("<") || !line.contains(">") {
                return false;
            }
            
            # Check for common HTML tags
            let html_tags = ["div", "span", "p", "h1", "h2", "h3", "h4", "h5", "h6",
                            "a", "button", "input", "form", "table", "tr", "td", "th",
                            "ul", "ol", "li", "img", "script", "style", "link", "meta",
                            "header", "footer", "nav", "section", "article", "aside",
                            "main", "br", "hr", "label", "select", "option", "textarea"];
            
            let lower = line.toLower();
            for tag in html_tags {
                let pattern = "<" + tag;
                if lower.contains(pattern) {
                    return true;
                }
            }
            
            return false;
        }
        
        fn _extract_markup(self, line: String) -> String {
            # Extract the markup portion
            let start = line.indexOf("<");
            let end = line.indexOf(">") + 1;
            if start >= 0 && end > start {
                return line.substring(start, end);
            }
            return line;
        }
        
        # Check for toHtml() usage
        pub fn check_toHtml(self, source: String, file: String) -> Self {
            let lines = source.split("\n");
            for i in range(lines.len()) {
                let line = lines[i];
                if line.contains("toHtml()") {
                    self.violations.push(LintViolation {
                        file: file,
                        line: i + 1,
                        column: 0,
                        message: "toHtml() not allowed in pure NyUI mode",
                        severity: "error",
                        code: "NYUI002"
                    });
                }
            }
            return self;
        }
        
        # Check for compileToJs() usage
        pub fn check_compileToJs(self, source: String, file: String) -> Self {
            let lines = source.split("\n");
            for i in range(lines.len()) {
                let line = lines[i];
                if line.contains("compileToJs()") {
                    self.violations.push(LintViolation {
                        file: file,
                        line: i + 1,
                        column: 0,
                        message: "compileToJs() not allowed in pure NyUI mode",
                        severity: "error",
                        code: "NYUI003"
                    });
                }
            }
            return self;
        }
        
        # Check for HTML element builders (div, span, etc.)
        pub fn check_html_builders(self, source: String, file: String) -> Self {
            let html_builders = ["div(", "span(", "p(", "h1(", "h2(", "h3(",
                                "button(", "input(", "form(", "a(", "ul(", "ol(",
                                "li(", "table(", "tr(", "td(", "th(", "img(", "script(",
                                "style(", "link(", "meta(", "br(", "hr("];
            
            let lines = source.split("\n");
            for i in range(lines.len()) {
                let line = lines[i];
                for builder in html_builders {
                    if line.contains(builder) {
                        self.violations.push(LintViolation {
                            file: file,
                            line: i + 1,
                            column: 0,
                            message: "HTML builder '" + builder + "' not allowed in pure NyUI mode. Use ui.Container, ui.Text, etc.",
                            severity: "error",
                            code: "NYUI004"
                        });
                    }
                }
            }
            return self;
        }
        
        # Run all checks
        pub fn check_all(self, source: String, file: String) -> Self {
            self.check_source(source, file);
            self.check_toHtml(source, file);
            self.check_compileToJs(source, file);
            self.check_html_builders(source, file);
            return self;
        }
        
        # Has errors
        pub fn has_errors(self) -> Bool {
            for v in self.violations {
                if v.severity == "error" {
                    return true;
                }
            }
            return false;
        }
    }
    
    # Lint violation
    pub class LintViolation {
        pub let file: String;
        pub let line: Int;
        pub let column: Int;
        pub let message: String;
        pub let severity: String;
        pub let code: String;
    }
    
    # Lint result
    pub class LintResult {
        pub let errors: Int;
        pub let warnings: Int;
        pub let violations: List<LintViolation>;
        
        pub fn new() -> Self {
            return Self {
                errors: 0,
                warnings: 0,
                violations: []
            };
        }
        
        pub fn from_detector(detector: MarkupStringDetector) -> Self {
            let result = Self::new();
            result.violations = detector.violations;
            for v in detector.violations {
                if v.severity == "error" {
                    result.errors = result.errors + 1;
                } else {
                    result.warnings = result.warnings + 1;
                }
            }
            return result;
        }
    }
}

# ============================================================
# BUILD FLAGS - Command Line Enforcement
# ============================================================

pub mod build {
    # Build flags for strict mode
    pub class BuildFlags {
        pub let ui_only: Bool;
        pub let pure_nyui: Bool;
        pub let strict: Bool;
        pub let enforce_config: Bool;
        
        pub fn new() -> Self {
            return Self {
                ui_only: false,
                pure_nyui: false,
                strict: false,
                enforce_config: true
            };
        }
        
        # Parse from command line args
        pub fn from_args(args: List<String>) -> Self {
            let flags = Self::new();
            
            for arg in args {
                if arg == "--ui-only" {
                    flags.ui_only = true;
                }
                if arg == "--pure-nyui" {
                    flags.pure_nyui = true;
                }
                if arg == "--strict" {
                    flags.strict = true;
                }
                if arg == "--no-config-enforce" {
                    flags.enforce_config = false;
                }
            }
            
            return flags;
        }
        
        # Is pure mode enabled
        pub fn is_pure(self) -> Bool {
            return self.ui_only || self.pure_nyui || self.strict;
        }
    }
    
    # Validation error
    pub class ValidationError {
        pub let message: String;
        pub let code: String;
        pub let file: String;
        pub let line: Int;
        
        pub fn new(message: String, code: String) -> Self {
            return Self {
                message: message,
                code: code,
                file: "",
                line: 0
            };
        }
    }
    
    # Validate build request
    pub class BuildValidator {
        pub let flags: BuildFlags;
        pub let config: config.UIProjectConfig;
        pub let errors: List<ValidationError>;
        
        pub fn new(flags: BuildFlags, config: config.UIProjectConfig) -> Self {
            return Self {
                flags: flags,
                config: config,
                errors: []
            };
        }
        
        # Validate the build request
        pub fn validate(self) -> Bool {
            # If pure mode flag is set, enforce it
            if self.flags.is_pure() && self.config.mode != config.UIMode::Pure {
                self.errors.push(ValidationError::new(
                    "Build flag --ui-only or --pure-nyui requires [ui] mode = \"pure\" in nyx.toml",
                    "BUILD001"
                ));
            }
            
            # If config says pure, but no flag, warn
            if self.config.is_pure() && !self.flags.is_pure() {
                # Just a warning, not an error
            }
            
            return self.errors.len() == 0;
        }
        
        # Get errors as string
        pub fn error_message(self) -> String {
            let msg = "";
            for err in self.errors {
                msg = msg + "Error [" + err.code + "]: " + err.message + "\n";
            }
            return msg;
        }
    }
}

# ============================================================
# NYIR COMPILER - Replace TemplateCompiler
# ============================================================

pub mod compiler {
    use nydom::*;
    
    # NyIR Compiler - compiles to intermediate representation
    pub class NyIRCompiler {
        pub let backend: renderer.RenderBackend;
        
        pub fn new(backend: renderer.RenderBackend) -> Self {
            return Self {
                backend: backend
            };
        }
        
        # Compile NyDOM to NyBytecode
        pub fn compile(self, tree: NyDomTree) -> NyBytecode {
            let bc = NyBytecode::new();
            self._compile_node(tree.root, bc);
            
            # Add style rules as instructions
            for style in tree.styles {
                bc.add(NyInstruction::CreateElement {
                    component: "Style",
                    props: { "selector": style.selector, "properties": style.properties }
                });
            }
            
            return bc;
        }
        
        # Compile to target-specific output
        pub fn compile_to_target(self, tree: NyDomTree) -> Any {
            match self.backend {
                renderer.RenderBackend::Web => return self._compile_web(tree),
                renderer.RenderBackend::WASM => return self._compile_wasm(tree),
                _ => return self.compile(tree)
            }
        }
        
        fn _compile_node(self, node: NyNode, bc: NyBytecode) {
            match node.node_type {
                NyNodeType::Text => {
                    bc.add(NyInstruction::CreateText {
                        content: node.props.get("content") as String
                    });
                },
                NyNodeType::Fragment => {
                    bc.add(NyInstruction::CreateFragment {
                        count: node.children.len()
                    });
                    for child in node.children {
                        self._compile_node(child, bc);
                    }
                },
                _ => {
                    # Create element instruction
                    bc.add(NyInstruction::CreateElement {
                        component: node.component_type,
                        props: node.props
                    });
                    
                    # Set key if present
                    if node.key != "" {
                        bc.add(NyInstruction::SetKey { key: node.key });
                    }
                    
                    # Set events
                    for event_name, _ in node.events {
                        bc.add(NyInstruction::SetEvent {
                            event: event_name,
                            handler_id: 0  # Would be actual handler ID in real impl
                        });
                    }
                    
                    # Compile children
                    for child in node.children {
                        self._compile_node(child, bc);
                        bc.add(NyInstruction::AddChild);
                    }
                }
            }
        }
        
        fn _compile_web(self, tree: NyDomTree) -> Any {
            # Compile to web-compatible format
            return self.compile(tree);
        }
        
        fn _compile_wasm(self, tree: NyDomTree) -> Any {
            # Compile to WASM format
            return self.compile(tree);
        }
    }
}

# ============================================================
# ROUTER - Pure Mode Compatible
# ============================================================

pub mod router {
    use nydom::*;
    
    # Route definition
    pub class Route {
        pub let path: String;
        pub let method: String;
        pub let handler: fn(Map<String, String>) -> NyNode;
        pub let name: String;
        
        pub fn new(path: String, method: String, handler: fn(Map<String, String>) -> NyNode) -> Self {
            return Self {
                path: path,
                method: method,
                handler: handler,
                name: ""
            };
        }
    }
    
    # Pure mode router - returns NyNode, not HTML
    pub class PureRouter {
        pub let routes: List<Route>;
        pub let current_path: String;
        pub let params: Map<String, String>;
        
        pub fn new() -> Self {
            return Self {
                routes: [],
                current_path: "/",
                params: {}
            };
        }
        
        # Add GET route
        pub fn get(self, path: String, handler: fn(Map<String, String>) -> NyNode) -> Self {
            self.routes.push(Route::new(path, "GET", handler));
            return self;
        }
        
        # Navigate - returns NyNode, not HTML string
        pub fn navigate(self, path: String) -> NyNode {
            self.current_path = path;
            self.params = self._matchRoute(path);
            return self.view();
        }
        
        # Get current view as NyNode (not HTML!)
        pub fn view(self) -> NyNode {
            for route in self.routes {
                if self._pathMatches(route.path, self.current_path) {
                    return route.handler(self.params);
                }
            }
            
            # Default 404
            return NyNode::new("Container").props({ "class": "not-found" })
                .children([NyNode::text("404 - Page Not Found")]);
        }
        
        fn _pathMatches(self, pattern: String, path: String) -> Bool {
            if pattern == path { return true; }
            
            let pattern_parts = pattern.split("/");
            let path_parts = path.split("/");
            
            if pattern_parts.len() != path_parts.len() { return false; }
            
            for i in range(pattern_parts.len()) {
                if pattern_parts[i].starts_with(":") { continue; }
                if pattern_parts[i] != path_parts[i] { return false; }
            }
            
            return true;
        }
        
        fn _matchRoute(self, path: String) -> Map<String, String> {
            let params: Map<String, String> = {};
            
            for route in self.routes {
                if self._pathMatches(route.path, path) {
                    let pattern_parts = route.path.split("/");
                    let path_parts = path.split("/");
                    
                    for i in range(pattern_parts.len()) {
                        if pattern_parts[i].starts_with(":") {
                            let key = pattern_parts[i].substring(1);
                            params.set(key, path_parts[i]);
                        }
                    }
                    
                    return params;
                }
            }
            
            return {};
        }
    }
}

# ============================================================
# COMPONENT SYSTEM - Pure Mode
# ============================================================

pub mod components {
    use nydom::*;
    
    # Component function type - returns NyNode
    pub type ComponentFn = fn(Map<String, Any>) -> NyNode;
    
    # Pure component
    pub class PureComponent {
        pub let name: String;
        pub let render: ComponentFn;
        
        pub fn new(name: String, render: ComponentFn) -> Self {
            return Self {
                name: name,
                render: render
            };
        }
        
        # Render component
        pub fn render(self, props: Map<String, Any>) -> NyNode {
            return self.render(props);
        }
    }
    
    # Component builder
    pub fn component(name: String, render: fn(Map<String, Any>) -> NyNode) -> PureComponent {
        return PureComponent::new(name, render);
    }
}

# ============================================================
# MAIN EXPORTS
# ============================================================

pub mod nyui_strict {
    # Version
    pub let VERSION = NYUI_STRICT_VERSION;
    
    # Configuration
    pub let UIMode = config.UIMode;
    pub let UIProjectConfig = config.UIProjectConfig;
    pub let PureModeConfig = config.PureModeConfig;
    pub let parse_toml_config = config.parse_toml_config;
    
    # NyDOM
    pub let NyNode = nydom.NyNode;
    pub let NyNodeType = nydom.NyNodeType;
    pub let NyDomTree = nydom.NyDomTree;
    pub let NyBytecode = nydom.NyBytecode;
    pub let NyStyleRule = nydom.NyStyleRule;
    
    # Renderer
    pub let NyRenderer = renderer.NyRenderer;
    pub let RenderBackend = renderer.RenderBackend;
    pub let WebRenderer = renderer.WebRenderer;
    
    # UI Components
    pub let Container = ui.Container;
    pub let Text = ui.Text;
    pub let Button = ui.Button;
    pub let Input = ui.Input;
    pub let List = ui.List;
    pub let ListItem = ui.ListItem;
    pub let Image = ui.Image;
    pub let Link = ui.Link;
    pub let Form = ui.Form;
    pub let Card = ui.Card;
    pub let Grid = ui.Grid;
    pub let Flex = ui.Flex;
    pub let Stack = ui.Stack;
    pub let Spacer = ui.Spacer;
    pub let Icon = ui.Icon;
    pub let Avatar = ui.Avatar;
    pub let Badge = ui.Badge;
    pub let Modal = ui.Modal;
    pub let Drawer = ui.Drawer;
    pub let Toolbar = ui.Toolbar;
    pub let Menu = ui.Menu;
    pub let MenuItem = ui.MenuItem;
    pub let Table = ui.Table;
    pub let TableRow = ui.TableRow;
    pub let TableCell = ui.TableCell;
    pub let Tabs = ui.Tabs;
    pub let Tab = ui.Tab;
    pub let Fragment = ui.Fragment;
    pub let If = ui.If;
    pub let For = ui.For;
    
    # Styles
    pub let style = styles.style;
    pub let StyleBuilder = styles.StyleBuilder;
    
    # Lint
    pub let MarkupStringDetector = lint.MarkupStringDetector;
    pub let LintViolation = lint.LintViolation;
    pub let LintResult = lint.LintResult;
    
    # Build
    pub let BuildFlags = build.BuildFlags;
    pub let BuildValidator = build.BuildValidator;
    pub let ValidationError = build.ValidationError;
    
    # Compiler
    pub let NyIRCompiler = compiler.NyIRCompiler;
    
    # Router
    pub let PureRouter = router.PureRouter;
    pub let Route = router.Route;
    
    # Components
    pub let PureComponent = components.PureComponent;
    pub let component = components.component;
}
