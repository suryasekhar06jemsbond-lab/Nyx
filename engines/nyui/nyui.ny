# ============================================================
# NYUI - Native UI Framework for Nyx
# ============================================================
# A comprehensive UI framework providing:
# - View DSL for declarative UI
# - Reactive Component Model
# - Event Binding System
# - Router DSL
# - SSR Support
# - Form & Data Binding
#
# Version: 1.0.0

let NYUI_VERSION = "1.0.0";

# Orchestrated imports: `import nyui` exposes strict + desktop APIs too.
use nyui_strict;
use nygui;
use nyweb;

# ============================================================
# VNODE - Virtual DOM Node
# ============================================================

# Virtual Node types
pub enum VNodeType {
    Element,
    Text,
    Component,
    Fragment
}

# Virtual DOM Node
pub class VNode {
    pub let tag: String;
    pub let type: VNodeType;
    pub let attrs: Map<String, Any>;
    pub let children: List<VNode>;
    pub let events: Map<String, fn(Event) -> Any>;
    pub let key: String;
    pub let ref: Any;
    
    # For components
    pub let component: Any;
    pub let props: Map<String, Any>;
    
    pub fn new(tag: String) -> Self {
        return Self {
            tag: tag,
            type: VNodeType::Element,
            attrs: {},
            children: [],
            events: {},
            key: "",
            ref: null,
            component: null,
            props: {}
        };
    }
    
    # Static text node
    pub fn text(content: String) -> Self {
        return Self {
            tag: "#text",
            type: VNodeType::Text,
            attrs: {},
            children: [],
            events: {},
            key: "",
            ref: null,
            component: null,
            props: {}
        };
    }
    
    # Set attribute
    pub fn attr(self, key: String, value: Any) -> Self {
        self.attrs.set(key, value);
        return self;
    }
    
    # Set multiple attributes
    pub fn attrs(self, attrs: Map<String, Any>) -> Self {
        for k, v in attrs {
            self.attrs.set(k, v);
        }
        return self;
    }
    
    # Add child node
    pub fn child(self, child: VNode) -> Self {
        self.children.push(child);
        return self;
    }
    
    # Add multiple children
    pub fn children(self, children: List<VNode>) -> Self {
        for c in children {
            self.children.push(c);
        }
        return self;
    }
    
    # Add text content
    pub fn textContent(self, text: String) -> Self {
        self.children.push(VNode::text(text));
        return self;
    }
    
    # Add event handler
    pub fn on(self, event: String, handler: fn(Event) -> Any) -> Self {
        self.events.set(event, handler);
        return self;
    }
    
    # Set key for reconciliation
    pub fn key(self, key: String) -> Self {
        self.key = key;
        return self;
    }
    
    # Set ref callback
    pub fn ref(self, ref: Any) -> Self {
        self.ref = ref;
        return self;
    }
    
    # Convert to HTML string
    pub fn toHtml(self) -> String {
        if self.type == VNodeType::Text {
            return self._escapeHtml(self.tag);
        }
        
        if self.tag == "" || self.tag == "fragment" {
            let result = "";
            for child in self.children {
                result = result + child.toHtml();
            }
            return result;
        }
        
        # Build attributes
        let attrs_str = "";
        for k, v in self.attrs {
            if v != null && v != false {
                let attr_val = if v == true { "" } else { "=\"" + self._escapeHtml(v as String) + "\"" };
                attrs_str = attrs_str + " " + k + attr_val;
            }
        }
        
        # Build children
        let children_html = "";
        for child in self.children {
            children_html = children_html + child.toHtml();
        }
        
        # Self-closing or regular tag
        let self_closing = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"];
        let is_self_closing = false;
        for t in self_closing {
            if t == self.tag.toLower() {
                is_self_closing = true;
            }
        }
        
        if is_self_closing {
            return "<" + self.tag + attrs_str + " />";
        }
        
        return "<" + self.tag + attrs_str + ">" + children_html + "</" + self.tag + ">";
    }
    
    fn _escapeHtml(self, text: String) -> String {
        return text
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
            .replace("'", "&#39;");
    }
}

# ============================================================
# ELEMENT BUILDERS - DSL Functions
# ============================================================

# HTML element builders - these create a declarative DSL

pub fn html(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("html").attrs(attrs).children(children);
}

pub fn head(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("head").attrs(attrs).children(children);
}

pub fn body(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("body").attrs(attrs).children(children);
}

pub fn div(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("div").attrs(attrs).children(children);
}

pub fn span(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("span").attrs(attrs).children(children);
}

pub fn p(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("p").attrs(attrs).children(children);
}

pub fn h1(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("h1").attrs(attrs).children(children);
}

pub fn h2(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("h2").attrs(attrs).children(children);
}

pub fn h3(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("h3").attrs(attrs).children(children);
}

pub fn h4(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("h4").attrs(attrs).children(children);
}

pub fn h5(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("h5").attrs(attrs).children(children);
}

pub fn h6(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("h6").attrs(attrs).children(children);
}

pub fn a(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("a").attrs(attrs).children(children);
}

pub fn button(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("button").attrs(attrs).children(children);
}

pub fn input(attrs: Map<String, Any>) -> VNode {
    return VNode::new("input").attrs(attrs);
}

pub fn textarea(attrs: Map<String, Any>) -> VNode {
    return VNode::new("textarea").attrs(attrs);
}

pub fn select(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("select").attrs(attrs).children(children);
}

pub fn option(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("option").attrs(attrs).children(children);
}

pub fn form(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("form").attrs(attrs).children(children);
}

pub fn label(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("label").attrs(attrs).children(children);
}

pub fn ul(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("ul").attrs(attrs).children(children);
}

pub fn ol(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("ol").attrs(attrs).children(children);
}

pub fn li(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("li").attrs(attrs).children(children);
}

pub fn table(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("table").attrs(attrs).children(children);
}

pub fn tr(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("tr").attrs(attrs).children(children);
}

pub fn th(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("th").attrs(attrs).children(children);
}

pub fn td(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("td").attrs(attrs).children(children);
}

pub fn thead(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("thead").attrs(attrs).children(children);
}

pub fn tbody(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("tbody").attrs(attrs).children(children);
}

pub fn img(attrs: Map<String, Any>) -> VNode {
    return VNode::new("img").attrs(attrs);
}

pub fn script(attrs: Map<String, Any>) -> VNode {
    return VNode::new("script").attrs(attrs);
}

pub fn link(attrs: Map<String, Any>) -> VNode {
    return VNode::new("link").attrs(attrs);
}

pub fn meta(attrs: Map<String, Any>) -> VNode {
    return VNode::new("meta").attrs(attrs);
}

pub fn title(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("title").attrs(attrs).children(children);
}

pub fn style(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("style").attrs(attrs).children(children);
}

pub fn nav(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("nav").attrs(attrs).children(children);
}

pub fn main(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("main").attrs(attrs).children(children);
}

pub fn section(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("section").attrs(attrs).children(children);
}

pub fn article(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("article").attrs(attrs).children(children);
}

pub fn aside(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("aside").attrs(attrs).children(children);
}

pub fn footer(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("footer").attrs(attrs).children(children);
}

pub fn header(attrs: Map<String, Any>, children: List<VNode>) -> VNode {
    return VNode::new("header").attrs(attrs).children(children);
}

pub fn br() -> VNode {
    return VNode::new("br");
}

pub fn hr() -> VNode {
    return VNode::new("hr");
}

pub fn text(content: String) -> VNode {
    return VNode::text(content);
}

# ============================================================
# REACTIVE STATE SYSTEM
# ============================================================

# Reactive value wrapper
pub class Reactive<T> {
    pub let value: T;
    let _subscribers: List<fn(T) -> Any>;
    
    pub fn new(initial: T) -> Self {
        return Self {
            value: initial,
            _subscribers: []
        };
    }
    
    # Set value and notify subscribers
    pub fn set(self, new_value: T) {
        self.value = new_value;
        self._notify();
    }
    
    # Subscribe to changes
    pub fn subscribe(self, callback: fn(T) -> Any) {
        self._subscribers.push(callback);
    }
    
    fn _notify(self) {
        for callback in self._subscribers {
            callback(self.value);
        }
    }
}

# Computed reactive value
pub class Computed<T> {
    pub let value: T;
    let _compute: fn() -> T;
    let _deps: List<Reactive<Any>>;
    let _subscribers: List<fn(T) -> Any>;
    
    pub fn new(compute: fn() -> T, deps: List<Reactive<Any>>) -> Self {
        let value = compute();
        
        # Subscribe to dependencies
        for dep in deps {
            dep.subscribe(fn(_) {
                self._recompute();
            });
        }
        
        return Self {
            value: value,
            _compute: compute,
            _deps: deps,
            _subscribers: []
        };
    }
    
    fn _recompute(self) {
        self.value = self._compute();
        self._notify();
    }
    
    pub fn subscribe(self, callback: fn(T) -> Any) {
        self._subscribers.push(callback);
    }
    
    fn _notify(self) {
        for callback in self._subscribers {
            callback(self.value);
        }
    }
}

# Signal - simpler reactive primitive
pub class Signal<T> {
    pub let value: T;
    let _callbacks: List<fn(T) -> Any>;
    
    pub fn new(initial: T) -> Self {
        return Self {
            value: initial,
            _callbacks: []
        };
    }
    
    pub fn update(self, updater: fn(T) -> T) {
        self.value = updater(self.value);
        self._notify();
    }
    
    pub fn onChange(self, callback: fn(T) -> Any) {
        self._callbacks.push(callback);
    }
    
    fn _notify(self) {
        for cb in self._callbacks {
            cb(self.value);
        }
    }
}

# ============================================================
# EVENT SYSTEM
# ============================================================

pub class Event {
    pub let type: String;
    pub let target: Any;
    pub let currentTarget: Any;
    pub let bubbles: Bool;
    pub let cancelable: Bool;
    pub let defaultPrevented: Bool;
    pub let props: Map<String, Any>;
    
    pub fn new(type: String) -> Self {
        return Self {
            type: type,
            target: null,
            currentTarget: null,
            bubbles: true,
            cancelable: true,
            defaultPrevented: false,
            props: {}
        };
    }
    
    pub fn preventDefault(self) {
        self.defaultPrevented = true;
    }
    
    pub fn stopPropagation(self) {
        self.bubbles = false;
    }
}

# Event handler helper
pub fn handler(name: String, callback: fn(Event) -> Any) -> (String, fn(Event) -> Any) {
    return (name, callback);
}

# Common event shorthand builders
pub fn onClick(handler: fn(Event) -> Any) -> (String, fn(Event) -> Any) {
    return ("click", handler);
}

pub fn onInput(handler: fn(Event) -> Any) -> (String, fn(Event) -> Any) {
    return ("input", handler);
}

pub fn onChange(handler: fn(Event) -> Any) -> (String, fn(Event) -> Any) {
    return ("change", handler);
}

pub fn onSubmit(handler: fn(Event) -> Any) -> (String, fn(Event) -> Any) {
    return ("submit", handler);
}

pub fn onFocus(handler: fn(Event) -> Any) -> (String, fn(Event) -> Any) {
    return ("focus", handler);
}

pub fn onBlur(handler: fn(Event) -> Any) -> (String, fn(Event) -> Any) {
    return ("blur", handler);
}

pub fn onKeyDown(handler: fn(Event) -> Any) -> (String, fn(Event) -> Any) {
    return ("keydown", handler);
}

pub fn onKeyUp(handler: fn(Event) -> Any) -> (String, fn(Event) -> Any) {
    return ("keyup", handler);
}

pub fn onMouseOver(handler: fn(Event) -> Any) -> (String, fn(Event) -> Any) {
    return ("mouseover", handler);
}

pub fn onMouseOut(handler: fn(Event) -> Any) -> (String, fn(Event) -> Any) {
    return ("mouseout", handler);
}

# ============================================================
# ROUTER DSL
# ============================================================

pub class Route {
    pub let path: String;
    pub let method: String;
    pub let handler: fn(Map<String, String>) -> VNode;
    pub let name: String;
    pub let guards: List<fn() -> Bool>;
    
    pub fn new(path: String, method: String, handler: fn(Map<String, String>) -> VNode) -> Self {
        return Self {
            path: path,
            method: method,
            handler: handler,
            name: "",
            guards: []
        };
    }
    
    pub fn withName(self, name: String) -> Self {
        self.name = name;
        return self;
    }
    
    pub fn withGuard(self, guard: fn() -> Bool) -> Self {
        self.guards.push(guard);
        return self;
    }
}

pub class Router {
    pub let routes: List<Route>;
    pub let currentPath: Signal<String>;
    pub let currentParams: Signal<Map<String, String>>;
    let _notFound: fn(Map<String, String>) -> VNode;
    
    pub fn new() -> Self {
        return Self {
            routes: [],
            currentPath: Signal::new("/"),
            currentParams: Signal::new({}),
            _notFound: fn(params) -> VNode {
                return div({"class": "not-found"}, [text("404 - Page Not Found")]);
            }
        };
    }
    
    # Add GET route
    pub fn get(self, path: String, handler: fn(Map<String, String>) -> VNode) -> Self {
        let route = Route::new(path, "GET", handler);
        self.routes.push(route);
        return self;
    }
    
    # Add POST route
    pub fn post(self, path: String, handler: fn(Map<String, String>) -> VNode) -> Self {
        let route = Route::new(path, "POST", handler);
        self.routes.push(route);
        return self;
    }
    
    # Add PUT route
    pub fn put(self, path: String, handler: fn(Map<String, String>) -> VNode) -> Self {
        let route = Route::new(path, "PUT", handler);
        self.routes.push(route);
        return self;
    }
    
    # Add DELETE route
    pub fn delete(self, path: String, handler: fn(Map<String, String>) -> VNode) -> Self {
        let route = Route::new(path, "DELETE", handler);
        self.routes.push(route);
        return self;
    }
    
    # Add route with any method
    pub fn any(self, path: String, handler: fn(Map<String, String>) -> VNode) -> Self {
        let route = Route::new(path, "ANY", handler);
        self.routes.push(route);
        return self;
    }
    
    # Set 404 handler
    pub fn notFound(self, handler: fn(Map<String, String>) -> VNode) -> Self {
        self._notFound = handler;
        return self;
    }
    
    # Navigate to path
    pub fn navigate(self, path: String) {
        self.currentPath.set(path);
        let params = self._matchRoute(path);
        self.currentParams.set(params);
    }
    
    # Get current view
    pub fn view(self) -> VNode {
        let path = self.currentPath.value;
        let params = self._matchRoute(path);
        
        for route in self.routes {
            if self._pathMatches(route.path, path) {
                # Check guards
                let allowed = true;
                for guard in route.guards {
                    if !guard() {
                        allowed = false;
                    }
                }
                
                if allowed {
                    return route.handler(params);
                }
            }
        }
        
        return self._notFound(params);
    }
    
    fn _matchRoute(self, path: String) -> Map<String, String> {
        for route in self.routes {
            if self._pathMatches(route.path, path) {
                return self._extractParams(route.path, path);
            }
        }
        return {};
    }
    
    fn _pathMatches(self, pattern: String, path: String) -> Bool {
        if pattern == path {
            return true;
        }
        
        let pattern_parts = pattern.split("/");
        let path_parts = path.split("/");
        
        if pattern_parts.len() != path_parts.len() {
            return false;
        }
        
        for i in range(pattern_parts.len()) {
            if pattern_parts[i].starts_with(":") {
                continue;
            }
            if pattern_parts[i] != path_parts[i] {
                return false;
            }
        }
        
        return true;
    }
    
    fn _extractParams(self, pattern: String, path: String) -> Map<String, String> {
        let params = {};
        let pattern_parts = pattern.split("/");
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

# ============================================================
# COMPONENT SYSTEM
# ============================================================

# Component function type
pub type ComponentFn = fn(Map<String, Any>) -> VNode;

# Component definition
pub class Component {
    pub let name: String;
    pub let render: ComponentFn;
    pub let props: Map<String, Any>;
    pub let state: Map<String, Any>;
    pub let methods: Map<String, fn(...Any) -> Any>;
    
    pub fn new(name: String, render: ComponentFn) -> Self {
        return Self {
            name: name,
            render: render,
            props: {},
            state: {},
            methods: {}
        };
    }
    
    # Set initial props
    pub fn withProps(self, props: Map<String, Any>) -> Self {
        self.props = props;
        return self;
    }
    
    # Render the component
    pub fn renderComponent(self) -> VNode {
        return self.render(self.props);
    }
}

# Component builder
pub fn component(name: String, render: fn(Map<String, Any>) -> VNode) -> Component {
    return Component::new(name, render);
}

# Fragment - renders multiple children without wrapper
pub fn fragment(children: List<VNode>) -> VNode {
    return VNode::new("").attrs({}).children(children);
}

# ============================================================
# FORM & DATA BINDING
# ============================================================

# Form field binding
pub class FormField<T> {
    pub let value: Signal<T>;
    pub let error: Signal<String>;
    pub let touched: Signal<Bool>;
    let _validators: List<fn(T) -> String>;
    
    pub fn new(initial: T) -> Self {
        return Self {
            value: Signal::new(initial),
            error: Signal::new(""),
            touched: Signal::new(false),
            _validators: []
        };
    }
    
    # Add validator
    pub fn validate(self, validator: fn(T) -> String) -> Self {
        self._validators.push(validator);
        return self;
    }
    
    # Run validation
    pub fn validateAll(self) -> Bool {
        self.touched.set(true);
        
        for validator in self._validators {
            let err = validator(self.value.value);
            if err != "" {
                self.error.set(err);
                return false;
            }
        }
        
        self.error.set("");
        return true;
    }
    
    # On change handler for input
    pub fn onChange(self, event: Event) {
        let new_value = event.props.get("value");
        self.value.set(new_value);
    }
}

# Form manager
pub class Form {
    pub let fields: Map<String, FormField<Any>>;
    pub let isValid: Signal<Bool>;
    pub let isSubmitting: Signal<Bool>;
    let _onSubmit: fn(Map<String, Any>) -> Any;
    
    pub fn new() -> Self {
        return Self {
            fields: {},
            isValid: Signal::new(true),
            isSubmitting: Signal::new(false),
            _onSubmit: fn(data) -> Any { return null; }
        };
    }
    
    # Add field
    pub fn field<T>(self, name: String, initial: T) -> FormField<T> {
        let field = FormField::new(initial);
        self.fields.set(name, field);
        return field;
    }
    
    # Set submit handler
    pub fn onSubmit(self, handler: fn(Map<String, Any>) -> Any) -> Self {
        self._onSubmit = handler;
        return self;
    }
    
    # Validate all fields
    pub fn validate(self) -> Bool {
        let valid = true;
        for name, field in self.fields {
            if !field.validateAll() {
                valid = false;
            }
        }
        self.isValid.set(valid);
        return valid;
    }
    
    # Get form data
    pub fn data(self) -> Map<String, Any> {
        let data = {};
        for name, field in self.fields {
            data.set(name, field.value.value);
        }
        return data;
    }
    
    # Submit form
    pub fn submit(self) {
        if self.validate() {
            self.isSubmitting.set(true);
            self._onSubmit(self.data());
            self.isSubmitting.set(false);
        }
    }
}

# ============================================================
# TEMPLATE COMPILER
# ============================================================

pub class TemplateCompiler {
    pub let mode: String;  # "static", "client", "ssr"
    
    pub fn new(mode: String) -> Self {
        return Self {
            mode: mode
        };
    }
    
    # Compile VNode to HTML string
    pub fn compile(self, vnode: VNode) -> String {
        return vnode.toHtml();
    }
    
    # Compile to client-side JavaScript
    pub fn compileToJs(self, vnode: VNode) -> String {
        return self._compileNode(vnode, 0);
    }
    
    fn _compileNode(self, node: VNode, depth: Int) -> String {
        let indent = self._indent(depth);
        
        if node.type == VNodeType::Text {
            return indent + "nyx.text(\"" + node.tag + "\")";
        }
        
        if node.tag == "" {
            # Fragment
            let children_code = "";
            for child in node.children {
                children_code = children_code + self._compileNode(child, depth + 1) + ",\n";
            }
            return indent + "nyx.fragment([" + children_code + "])";
        }
        
        # Build attributes
        let attrs_code = "{";
        let first = true;
        for k, v in node.attrs {
            if !first {
                attrs_code = attrs_code + ", ";
            }
            first = false;
            attrs_code = attrs_code + "\"" + k + "\": " + self._valueToJs(v);
        }
        attrs_code = attrs_code + "}";
        
        # Build children
        let children_code = "[";
        for child in node.children {
            children_code = children_code + self._compileNode(child, depth + 1) + ",\n";
        }
        children_code = children_code + "]";
        
        return indent + "nyx.\"" + node.tag + "\"(" + attrs_code + ", " + children_code + ")";
    }
    
    fn _valueToJs(self, value: Any) -> String {
        if value == null {
            return "null";
        }
        if value == true {
            return "true";
        }
        if value == false {
            return "false";
        }
        if value is String {
            return "\"" + value + "\"";
        }
        if value is Int || value is Float {
            return value as String;
        }
        return "null";
    }
    
    fn _indent(self, depth: Int) -> String {
        let result = "";
        for i in range(depth) {
            result = result + "    ";
        }
        return result;
    }
}

# ============================================================
# SSR (Server-Side Rendering)
# ============================================================

pub class SSR {
    pub let app: Any;
    pub let router: Router;
    
    pub fn new(app: Any) -> Self {
        return Self {
            app: app,
            router: Router::new()
        };
    }
    
    # Render view to HTML string
    pub fn render(self, path: String) -> String {
        self.router.navigate(path);
        let vnode = self.router.view();
        return vnode.toHtml();
    }
    
    # Render full HTML page
    pub fn renderPage(self, path: String, options: Map<String, Any>) -> String {
        let title = options.get("title") or "Nyx App";
        let styles = options.get("styles") or "";
        let scripts = options.get("scripts") or "";
        let content = self.render(path);
        
        return "<!DOCTYPE html>
<html>
<head>
    <meta charset=\"utf-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
    <title>" + title + "</title>
    " + styles + "
</head>
<body>
    <div id=\"app\">" + content + "</div>
    " + scripts + "
</body>
</html>";
    }
    
    # Stream render for progressive loading
    pub fn stream(self, path: String) -> List<String> {
        self.router.navigate(path);
        let vnode = self.router.view();
        
        # Return chunks for streaming
        let chunks = [];
        chunks.push("<!DOCTYPE html><html><head><meta charset=\"utf-8\"></head><body><div id=\"app\">");
        chunks.push(vnode.toHtml());
        chunks.push("</div></body></html>");
        
        return chunks;
    }
}

# ============================================================
# CLIENT RUNTIME
# ============================================================

pub class ClientRuntime {
    pub let container: String;
    pub let router: Router;
    let _rendered: Bool;
    
    pub fn new(container: String) -> Self {
        return Self {
            container: container,
            router: Router::new(),
            _rendered: false
        };
    }
    
    # Mount the app
    pub fn mount(self) {
        self._rendered = true;
        # In browser, this would manipulate the DOM
    }
    
    # Re-render on state change
    pub fn rerender(self) {
        if self._rendered {
            let view = self.router.view();
            # In browser, would update DOM here
        }
    }
    
    # Navigate
    pub fn navigate(self, path: String) {
        self.router.navigate(path);
        self.rerender();
    }
}

# ============================================================
# VNODE DIFFING ALGORITHM
# ============================================================

pub class DiffResult {
    pub let updates: List<DOMUpdate>;
    pub let additions: List<VNode>;
    pub let removals: List<String>;
}

pub class DOMUpdate {
    pub let type: String;  # "setAttribute", "removeAttribute", "setTextContent", "addChild", "removeChild"
    pub let target: String;
    pub let key: String;
    pub let value: Any;
    
    pub fn new(type: String, target: String, key: String, value: Any) -> Self {
        return Self {
            type: type,
            target: target,
            key: key,
            value: value
        };
    }
}

pub fn diff(oldTree: VNode, newTree: VNode) -> DiffResult {
    let result = DiffResult {
        updates: [],
        additions: [],
        removals: []
    };
    
    # Simple diff - compare tags and children
    if oldTree.tag != newTree.tag {
        # Full replacement needed
        result.updates.push(DOMUpdate::new("replace", "", "", newTree.toHtml()));
        return result;
    }
    
    # Diff attributes
    for k, v in newTree.attrs {
        let old_v = oldTree.attrs.get(k);
        if old_v != v {
            result.updates.push(DOMUpdate::new("setAttribute", oldTree.tag, k, v));
        }
    }
    
    # Check for removed attributes
    for k, _ in oldTree.attrs {
        if !newTree.attrs.contains(k) {
            result.updates.push(DOMUpdate::new("removeAttribute", oldTree.tag, k, null));
        }
    }
    
    # Diff children
    let max_children = max(oldTree.children.len(), newTree.children.len());
    for i in range(max_children) {
        if i >= oldTree.children.len() {
            # New child
            result.additions.push(newTree.children[i]);
        } else if i >= newTree.children.len() {
            # Removed child
            result.removals.push(oldTree.tag + "-" + i as String);
        } else {
            # Recursive diff
            let child_result = diff(oldTree.children[i], newTree.children[i]);
            result.updates.extend(child_result.updates);
            result.additions.extend(child_result.additions);
            result.removals.extend(child_result.removals);
        }
    }
    
    return result;
}

# ============================================================
# NYX WEBSITE - Pure Nyx Website Builder + Browser Hosting
# ============================================================
# Build pages from strict NyUI component trees (NyNode), then:
# - render to browser HTML automatically
# - host with Nyweb HTTP server
# No raw HTML authoring is required in user .ny source.

pub class WebsiteRoute {
    pub let path: String;
    pub let handler: fn(Map<String, String>) -> nyui_strict.NyNode;

    pub fn new(path: String, handler: fn(Map<String, String>) -> nyui_strict.NyNode) -> Self {
        return Self {
            path: path,
            handler: handler
        };
    }
}

pub class NyxWebsite {
    pub let name: String;
    pub let title: String;
    pub let lang: String;
    pub let routes: List<WebsiteRoute>;
    pub let styles: List<nyui_strict.NyStyleRule>;
    pub let headMeta: Map<String, String>;

    pub fn new(name: String) -> Self {
        return Self {
            name: name,
            title: name,
            lang: "en",
            routes: [],
            styles: [],
            headMeta: {}
        };
    }

    pub fn pageTitle(self, title: String) -> Self {
        self.title = title;
        return self;
    }

    pub fn locale(self, lang: String) -> Self {
        self.lang = lang;
        return self;
    }

    pub fn withStyles(self, rules: List<nyui_strict.NyStyleRule>) -> Self {
        self.styles = rules;
        return self;
    }

    pub fn meta(self, name: String, content: String) -> Self {
        self.headMeta.set(name, content);
        return self;
    }

    pub fn get(self, path: String, handler: fn(Map<String, String>) -> nyui_strict.NyNode) -> Self {
        self.routes.push(WebsiteRoute::new(path, handler));
        return self;
    }

    pub fn render(self, path: String) -> String {
        let params = self._matchParams(path);
        let page = self._resolve(path, params);
        let body = strictToHtml(page);
        let themeText = strictStyleToTheme(self.styles);
        let head = "<meta charset=\"utf-8\" />" +
                   "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />" +
                   "<title>" + self.title + "</title>" +
                   self._renderMeta() +
                   (if themeText != "" { "<style>" + themeText + "</style>" } else { "" });

        return "<!DOCTYPE html><html lang=\"" + self.lang + "\"><head>" +
               head +
               "</head><body>" + body + "</body></html>";
    }

    pub fn run(self, host: String, port: Int) {
        let app = nyweb.Application::new(self.name);

        if self.routes.len() == 0 {
            self.get("/", fn(params: Map<String, String>) -> nyui_strict.NyNode {
                return nyui_strict.Container(
                    { "class": "empty-site" },
                    [nyui_strict.Text("No routes defined for this website.")]
                );
            });
        }

        for siteRoute in self.routes {
            let routePath = siteRoute.path;
            app.routes.push(nyweb.Route::new(
                routePath,
                ["GET"],
                fn(request: nyweb.Request) -> nyweb.Response {
                    let html = self.render(request.path);
                    return nyweb.Response::html(html);
                }
            ));
        }

        io.println("NyxWebsite running at http://" + host + ":" + port as String);
        app.run(host, port);
    }

    fn _resolve(self, path: String, params: Map<String, String>) -> nyui_strict.NyNode {
        for route in self.routes {
            if self._pathMatches(route.path, path) {
                return route.handler(params);
            }
        }

        return nyui_strict.Container(
            { "class": "not-found" },
            [nyui_strict.Text("404 - Page Not Found")]
        );
    }

    fn _pathMatches(self, pattern: String, path: String) -> Bool {
        if pattern == path { return true; }

        let patternParts = pattern.split("/");
        let pathParts = path.split("/");

        if patternParts.len() != pathParts.len() { return false; }

        for i in range(patternParts.len()) {
            let p = patternParts[i];
            let c = pathParts[i];
            if p.starts_with(":") { continue; }
            if p != c { return false; }
        }

        return true;
    }

    fn _matchParams(self, path: String) -> Map<String, String> {
        let params: Map<String, String> = {};

        for route in self.routes {
            if self._pathMatches(route.path, path) {
                let patternParts = route.path.split("/");
                let pathParts = path.split("/");

                for i in range(patternParts.len()) {
                    let p = patternParts[i];
                    if p.starts_with(":") {
                        params.set(p.substring(1), pathParts[i]);
                    }
                }

                return params;
            }
        }

        return params;
    }

    fn _renderMeta(self) -> String {
        let out = "";
        for k, v in self.headMeta {
            out = out + "<meta name=\"" + k + "\" content=\"" + v + "\" />";
        }
        return out;
    }
}

pub fn createWebsite(name: String) -> NyxWebsite {
    return NyxWebsite::new(name);
}

pub fn strictToHtml(node: nyui_strict.NyNode) -> String {
    return strictToVNode(node).toHtml();
}

pub fn strictToVNode(node: nyui_strict.NyNode) -> VNode {
    if node.node_type == nyui_strict.NyNodeType::Text {
        let textVal = node.props.get("content") or "";
        return VNode::text(textVal as String);
    }

    if node.node_type == nyui_strict.NyNodeType::Fragment {
        let parts: List<VNode> = [];
        for child in node.children {
            parts.push(strictToVNode(child));
        }
        return fragment(parts);
    }

    let tag = _strictComponentToTag(node.component_type);
    let v = VNode::new(tag);

    for key, value in node.props {
        if key == "content" { continue; }
        if key.starts_with("on") { continue; }
        v.attr(key, value);
    }

    for child in node.children {
        v.child(strictToVNode(child));
    }

    return v;
}

pub fn strictStyleToTheme(rules: List<nyui_strict.NyStyleRule>) -> String {
    let themeText = "";

    for rule in rules {
        let selector = _strictComponentToStyleSelector(rule.selector);
        let props = "";
        for k, v in rule.properties {
            let prop = _camelToKebab(k);
            props = props + prop + ": " + v as String + ";";
        }
        themeText = themeText + selector + "{" + props + "}";
    }

    return themeText;
}

fn _strictComponentToStyleSelector(name: String) -> String {
    if name == "" { return "*"; }
    if name.starts_with(".") { return name; }
    if name.starts_with("#") { return name; }
    if name.starts_with("[") { return name; }
    if name.starts_with(":") { return name; }
    if name == "*" { return name; }
    if name.contains(" ") { return name; }
    if name.contains(">") { return name; }
    if name.contains("+") { return name; }
    if name.contains("~") { return name; }
    return _strictComponentToTag(name);
}

fn _strictComponentToTag(name: String) -> String {
    if name == "Container" { return "div"; }
    if name == "Text" { return "span"; }
    if name == "Button" { return "button"; }
    if name == "Input" { return "input"; }
    if name == "List" { return "ul"; }
    if name == "ListItem" { return "li"; }
    if name == "Image" { return "img"; }
    if name == "Link" { return "a"; }
    if name == "Form" { return "form"; }
    if name == "Card" { return "article"; }
    if name == "Grid" { return "div"; }
    if name == "Flex" { return "div"; }
    if name == "Stack" { return "div"; }
    if name == "Spacer" { return "div"; }
    if name == "Icon" { return "span"; }
    if name == "Avatar" { return "img"; }
    if name == "Badge" { return "span"; }
    if name == "Modal" { return "dialog"; }
    if name == "Drawer" { return "aside"; }
    if name == "Toolbar" { return "header"; }
    if name == "Menu" { return "nav"; }
    if name == "MenuItem" { return "a"; }
    if name == "Table" { return "table"; }
    if name == "TableRow" { return "tr"; }
    if name == "TableCell" { return "td"; }
    if name == "Tabs" { return "section"; }
    if name == "Tab" { return "section"; }
    return "div";
}

fn _camelToKebab(input: String) -> String {
    return input
        .replace("fontSize", "font-size")
        .replace("fontWeight", "font-weight")
        .replace("borderRadius", "border-radius")
        .replace("flexDirection", "flex-direction")
        .replace("justifyContent", "justify-content")
        .replace("alignItems", "align-items")
        .replace("lineHeight", "line-height")
        .replace("letterSpacing", "letter-spacing")
        .replace("textTransform", "text-transform")
        .replace("whiteSpace", "white-space")
        .replace("wordBreak", "word-break")
        .replace("zIndex", "z-index");
}

# ============================================================
# EXPORTS
# ============================================================

pub mod nyui {
    # Version
    pub let VERSION = NYUI_VERSION;
    
    # Core
    pub let VNode = VNode;
    pub let VNodeType = VNodeType;
    
    # Element builders
    pub let html = html;
    pub let head = head;
    pub let body = body;
    pub let div = div;
    pub let span = span;
    pub let p = p;
    pub let h1 = h1;
    pub let h2 = h2;
    pub let h3 = h3;
    pub let h4 = h4;
    pub let h5 = h5;
    pub let h6 = h6;
    pub let a = a;
    pub let button = button;
    pub let input = input;
    pub let textarea = textarea;
    pub let select = select;
    pub let option = option;
    pub let form = form;
    pub let label = label;
    pub let ul = ul;
    pub let ol = ol;
    pub let li = li;
    pub let table = table;
    pub let tr = tr;
    pub let th = th;
    pub let td = td;
    pub let thead = thead;
    pub let tbody = tbody;
    pub let img = img;
    pub let script = script;
    pub let link = link;
    pub let meta = meta;
    pub let title = title;
    pub let style = style;
    pub let nav = nav;
    pub let main = main;
    pub let section = section;
    pub let article = article;
    pub let aside = aside;
    pub let footer = footer;
    pub let header = header;
    pub let br = br;
    pub let hr = hr;
    pub let text = text;
    pub let fragment = fragment;
    
    # Reactive
    pub let Reactive = Reactive;
    pub let Computed = Computed;
    pub let Signal = Signal;
    
    # Events
    pub let Event = Event;
    pub let handler = handler;
    pub let onClick = onClick;
    pub let onInput = onInput;
    pub let onChange = onChange;
    pub let onSubmit = onSubmit;
    pub let onFocus = onFocus;
    pub let onBlur = onBlur;
    pub let onKeyDown = onKeyDown;
    pub let onKeyUp = onKeyUp;
    pub let onMouseOver = onMouseOver;
    pub let onMouseOut = onMouseOut;
    
    # Router
    pub let Route = Route;
    pub let Router = Router;
    
    # Components
    pub let Component = Component;
    pub let component = component;
    
    # Forms
    pub let FormField = FormField;
    pub let Form = Form;
    
    # Compiler
    pub let TemplateCompiler = TemplateCompiler;
    
    # SSR
    pub let SSR = SSR;
    
    # Client
    pub let ClientRuntime = ClientRuntime;
    
    # Utils
    pub let diff = diff;
    pub let DiffResult = DiffResult;
    pub let DOMUpdate = DOMUpdate;

    # Orchestrator aliases (single-import UX)
    pub let strict = nyui_strict;
    pub let pure = nyui_strict;
    pub let gui = nygui;
    pub let desktop = nygui;

    # Desktop aliases (prefixed to avoid collisions with web builders)
    pub let GUIApplication = nygui.Application;
    pub let GUIWindow = nygui.Window;
    pub let GUIDialog = nygui.Dialog;
    pub let GUIWidget = nygui.Widget;
    pub let GUIButton = nygui.Button;
    pub let GUILabel = nygui.Label;
    pub let GUIEntry = nygui.Entry;
    pub let GUICanvas = nygui.Canvas;
    pub let GUIMenu = nygui.Menu;
    pub let GUIPack = nygui.Pack;
    pub let GUIGrid = nygui.Grid;
    pub let GUIPlace = nygui.Place;

    # Pure website (Nyx syntax only) + browser hosting
    pub let WebsiteRoute = WebsiteRoute;
    pub let NyxWebsite = NyxWebsite;
    pub let createWebsite = createWebsite;
    pub let strictToHtml = strictToHtml;
    pub let strictToVNode = strictToVNode;
    pub let strictStyleToTheme = strictStyleToTheme;
}
