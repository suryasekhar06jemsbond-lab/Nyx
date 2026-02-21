# Nyx Web Framework - Advanced UI Engine
# Virtual DOM with Diffing, Hydration, and Event System
#
# This module provides:
# - Virtual DOM with keyed diffing algorithm
# - Hydration (SSR → Client reactivity)
# - Event delegation system
# - Async rendering

pub mod nyui_advanced {
    
    # =========================================================================
    # VIRTUAL DOM WITH DIFFING
    # =========================================================================
    
    pub class VNode {
        pub let tag: String;
        pub let attrs: Dict<String, String>;
        pub let children: List<VNode>;
        pub let text: String?;
        pub let key: String?;
        pub let ref: String?;
        pub let dom_node: Any?;  # Reference to actual DOM node
        pub let event_handlers: Dict<String, fn(Event)>;
        
        pub fn new(tag: String) -> Self {
            return Self {
                tag: tag,
                attrs: {},
                children: [],
                text: null,
                key: null,
                ref: null,
                dom_node: null,
                event_handlers: {},
            };
        }
        
        pub fn text(content: String) -> Self {
            return Self {
                tag: "#text",
                attrs: {},
                children: [],
                text: content,
                key: null,
                ref: null,
                dom_node: null,
                event_handlers: {},
            };
        }
        
        pub fn attr(self, name: String, value: String) -> Self {
            self.attrs.set(name, value);
            return self;
        }
        
        pub fn on(self, event: String, handler: fn(Event)) -> Self {
            self.event_handlers.set(event, handler);
            return self;
        }
        
        pub fn child(self, child: VNode) -> Self {
            self.children.push(child);
            return self;
        }
        
        pub fn key(self, k: String) -> Self {
            self.key = k;
            return self;
        }
        
        pub fn ref(self, r: String) -> Self {
            self.ref = r;
            return self;
        }
    }
    
    # =========================================================================
    # DIFFING ALGORITHM (Reconciliation)
    # =========================================================================
    
    pub class DiffEngine {
        
        # Main diff function - returns list of patches
        pub fn diff(old: VNode?, new: VNode?) -> List<Patch> {
            let patches = [];
            
            # Both null - nothing to do
            if old == null && new == null {
                return patches;
            }
            
            # Old null, new exists - create
            if old == null && new != null {
                patches.push(Patch::create(new));
                return patches;
            }
            
            # Old exists, new null - remove
            if old != null && new == null {
                patches.push(Patch::remove(old));
                return patches;
            }
            
            # Both exist - compare
            let old_node = old as VNode;
            let new_node = new as VNode;
            
            # Different types - replace
            if old_node.tag != new_node.tag {
                patches.push(Patch::replace(old_node, new_node));
                return patches;
            }
            
            # Text nodes - compare text
            if old_node.tag == "#text" {
                if old_node.text != new_node.text {
                    patches.push(Patch::text(new_node));
                }
                return patches;
            }
            
            # Same tag - diff attributes and children
            let attr_patches = DiffEngine::diff_attrs(old_node.attrs, new_node.attrs);
            for patch in attr_patches {
                patches.push(patch);
            }
            
            # Diff children with keys
            let child_patches = DiffEngine::diff_children(old_node.children, new_node.children);
            for patch in child_patches {
                patches.push(patch);
            }
            
            return patches;
        }
        
        # Diff attributes
        fn diff_attrs(old: Dict<String, String>, new: Dict<String, String>) -> List<Patch> {
            let patches = [];
            
            # Check for changed or new attributes
            for (name, value) in new {
                let old_value = old.get(name);
                if old_value == null || old_value != value {
                    patches.push(Patch::attr(name, value));
                }
            }
            
            # Check for removed attributes
            for (name, value) in old {
                if new.get(name) == null {
                    patches.push(Patch::remove_attr(name));
                }
            }
            
            return patches;
        }
        
        # Diff children with keyed reconciliation
        fn diff_children(old: List<VNode>, new: List<VNode>) -> List<Patch> {
            let patches = [];
            
            # Build key maps
            let old_keyed = DiffEngine::build_key_map(old);
            let new_keyed = DiffEngine::build_key_map(new);
            
            # Track processed indices
            let processed_old = {};
            let processed_new = {};
            
            # First pass: match by key
            for (key, new_idx) in new_keyed {
                let old_idx = old_keyed.get(key);
                if old_idx != null {
                    # Key exists in both - diff the nodes
                    let child_patches = DiffEngine::diff(old[old_idx], new[new_idx]);
                    for patch in child_patches {
                        patches.push(patch);
                    }
                    processed_old.set(old_idx as String, true);
                    processed_new.set(new_idx as String, true);
                }
            }
            
            # Second pass: handle unkeyed nodes
            let old_unkeyed = [];
            let new_unkeyed = [];
            
            for i in range(old.len()) {
                if processed_old.get(i as String) == null {
                    old_unkeyed.push(i);
                }
            }
            
            for i in range(new.len()) {
                if processed_new.get(i as String) == null {
                    new_unkeyed.push(i);
                }
            }
            
            # Match unkeyed by position
            let min_len = old_unkeyed.len();
            if new_unkeyed.len() < min_len {
                min_len = new_unkeyed.len();
            }
            
            for i in range(min_len) {
                let old_idx = old_unkeyed[i];
                let new_idx = new_unkeyed[i];
                let child_patches = DiffEngine::diff(old[old_idx], new[new_idx]);
                for patch in child_patches {
                    patches.push(patch);
                }
            }
            
            # Extra new nodes - create
            for i in range(min_len, new_unkeyed.len()) {
                let new_idx = new_unkeyed[i];
                patches.push(Patch::create(new[new_idx]));
            }
            
            # Extra old nodes - remove
            for i in range(min_len, old_unkeyed.len()) {
                let old_idx = old_unkeyed[i];
                patches.push(Patch::remove(old[old_idx]));
            }
            
            return patches;
        }
        
        # Build map of key -> index
        fn build_key_map(nodes: List<VNode>) -> Dict<String, Int> {
            let map = {};
            for i in range(nodes.len()) {
                let node = nodes[i];
                if node.key != null {
                    map.set(node.key, i);
                }
            }
            return map;
        }
    }
    
    # =========================================================================
    # PATCH TYPES
    # =========================================================================
    
    pub class Patch {
        pub let type: String;
        pub let node: VNode?;
        pub let old_node: VNode?;
        pub let attr_name: String?;
        pub let attr_value: String?;
        pub let index: Int?;
        
        pub fn create(node: VNode) -> Self {
            return Self {
                type: "CREATE",
                node: node,
                old_node: null,
                attr_name: null,
                attr_value: null,
                index: null,
            };
        }
        
        pub fn remove(node: VNode) -> Self {
            return Self {
                type: "REMOVE",
                node: node,
                old_node: null,
                attr_name: null,
                attr_value: null,
                index: null,
            };
        }
        
        pub fn replace(old: VNode, new: VNode) -> Self {
            return Self {
                type: "REPLACE",
                node: new,
                old_node: old,
                attr_name: null,
                attr_value: null,
                index: null,
            };
        }
        
        pub fn text(node: VNode) -> Self {
            return Self {
                type: "TEXT",
                node: node,
                old_node: null,
                attr_name: null,
                attr_value: null,
                index: null,
            };
        }
        
        pub fn attr(name: String, value: String) -> Self {
            return Self {
                type: "ATTR",
                node: null,
                old_node: null,
                attr_name: name,
                attr_value: value,
                index: null,
            };
        }
        
        pub fn remove_attr(name: String) -> Self {
            return Self {
                type: "REMOVE_ATTR",
                node: null,
                old_node: null,
                attr_name: name,
                attr_value: null,
                index: null,
            };
        }
    }
    
    # =========================================================================
    # DOM RENDERER
    # =========================================================================
    
    pub class DOMRenderer {
        pub let root: Any;  # DOM element
        pub let current_vdom: VNode?;
        
        pub fn new(root_id: String) -> Self {
            return Self {
                root: document.getElementById(root_id),
                current_vdom: null,
            };
        }
        
        # Initial render
        pub fn render(self, vnode: VNode) {
            let dom = DOMRenderer::create_dom(vnode);
            self.root.innerHTML = "";
            self.root.appendChild(dom);
            self.current_vdom = vnode;
        }
        
        # Create DOM node from VNode
        fn create_dom(vnode: VNode) -> Any {
            if vnode.tag == "#text" {
                let text_node = document.createTextNode(vnode.text);
                vnode.dom_node = text_node;
                return text_node;
            }
            
            let el = document.createElement(vnode.tag);
            vnode.dom_node = el;
            
            # Set attributes
            for (name, value) in vnode.attrs {
                el.setAttribute(name, value);
            }
            
            # Attach event handlers
            for (event, handler) in vnode.event_handlers {
                el.addEventListener(event, handler);
            }
            
            # Create children
            for child in vnode.children {
                el.appendChild(DOMRenderer::create_dom(child));
            }
            
            return el;
        }
        
        # Apply patches to DOM
        pub fn apply_patches(self, patches: List<Patch>) {
            for patch in patches {
                DOMRenderer::apply_patch(patch);
            }
        }
        
        fn apply_patch(patch: Patch) {
            if patch.type == "CREATE" {
                let parent = patch.node.dom_node?.parentNode;
                if parent != null {
                    parent.appendChild(DOMRenderer::create_dom(patch.node));
                }
            } else if patch.type == "REMOVE" {
                if patch.node.dom_node != null {
                    patch.node.dom_node.remove();
                }
            } else if patch.type == "REPLACE" {
                if patch.old_node.dom_node != null && patch.node != null {
                    let new_dom = DOMRenderer::create_dom(patch.node);
                    patch.old_node.dom_node.replaceWith(new_dom);
                }
            } else if patch.type == "TEXT" {
                if patch.node.dom_node != null {
                    patch.node.dom_node.textContent = patch.node.text;
                }
            } else if patch.type == "ATTR" {
                if patch.node != null && patch.node.dom_node != null {
                    patch.node.dom_node.setAttribute(patch.attr_name, patch.attr_value);
                }
            } else if patch.type == "REMOVE_ATTR" {
                if patch.node != null && patch.node.dom_node != null {
                    patch.node.dom_node.removeAttribute(patch.attr_name);
                }
            }
        }
        
        # Update with new VDOM
        pub fn update(self, new_vdom: VNode) {
            let patches = DiffEngine::diff(self.current_vdom, new_vdom);
            self.apply_patches(patches);
            self.current_vdom = new_vdom;
        }
    }
    
    # =========================================================================
    # HYDRATION (SSR → Client)
    # =========================================================================
    
    pub class Hydrator {
        pub let root: Any;
        pub let vdom: VNode;
        pub let component_registry: Dict<String, Component>;
        
        pub fn new(root_id: String, vdom: VNode) -> Self {
            return Self {
                root: document.getElementById(root_id),
                vdom: vdom,
                component_registry: {},
            };
        }
        
        # Hydrate existing DOM with VDOM
        pub fn hydrate(self) -> Bool {
            return self._hydrate_node(self.root.firstChild, self.vdom);
        }
        
        fn _hydrate_node(self, dom_node: Any, vnode: VNode) -> Bool {
            if dom_node == null || vnode == null {
                return false;
            }
            
            # Link DOM node to VNode
            vnode.dom_node = dom_node;
            
            # Text node
            if vnode.tag == "#text" {
                if dom_node.nodeType != 3 {  # TEXT_NODE
                    return false;
                }
                return true;
            }
            
            # Element node
            if dom_node.nodeType != 1 {  # ELEMENT_NODE
                return false;
            }
            
            # Check tag matches
            if dom_node.tagName.to_lowercase() != vnode.tag.to_lowercase() {
                return false;
            }
            
            # Attach event handlers
            for (event, handler) in vnode.event_handlers {
                dom_node.addEventListener(event, handler);
            }
            
            # Hydrate children
            let dom_children = dom_node.childNodes;
            let vdom_children = vnode.children;
            
            let i = 0;
            for child in vdom_children {
                if i < dom_children.length {
                    self._hydrate_node(dom_children[i], child);
                }
                i = i + 1;
            }
            
            return true;
        }
        
        # Register component for reactivity
        pub fn register_component(self, id: String, component: Component) {
            self.component_registry.set(id, component);
        }
        
        # Get component by ID
        pub fn get_component(self, id: String) -> Component? {
            return self.component_registry.get(id);
        }
    }
    
    # =========================================================================
    # EVENT SYSTEM
    # =========================================================================
    
    pub class EventSystem {
        pub let handlers: Dict<String, List<fn(Event)>>;
        pub let delegated: Dict<String, fn(Event)>;
        
        pub fn new() -> Self {
            return Self {
                handlers: {},
                delegated: {},
            };
        }
        
        # Add event listener
        pub fn on(self, event: String, selector: String, handler: fn(Event)) {
            let key = event + ":" + selector;
            if self.handlers.get(key) == null {
                self.handlers.set(key, []);
            }
            self.handlers[key].push(handler);
        }
        
        # Remove event listener
        pub fn off(self, event: String, selector: String, handler: fn(Event)) {
            let key = event + ":" + selector;
            let handlers = self.handlers.get(key);
            if handlers != null {
                let new_handlers = [];
                for h in handlers {
                    if h != handler {
                        new_handlers.push(h);
                    }
                }
                self.handlers.set(key, new_handlers);
            }
        }
        
        # Delegate event handling
        pub fn delegate(self, root: Any, event: String) {
            root.addEventListener(event, fn(e) {
                self._handle_delegated(e, root);
            });
        }
        
        fn _handle_delegated(self, e: Event, root: Any) {
            let target = e.target;
            
            # Walk up the DOM tree
            while target != null && target != root {
                for (key, handlers) in self.handlers {
                    let parts = key.split(":");
                    if parts.len() != 2 {
                        continue;
                    }
                    
                    let event_type = parts[0];
                    let selector = parts[1];
                    
                    if event_type != e.type {
                        continue;
                    }
                    
                    if target.matches(selector) {
                        for handler in handlers {
                            handler(e);
                        }
                    }
                }
                
                target = target.parentNode;
            }
        }
        
        # Emit custom event
        pub fn emit(self, element: Any, event: String, detail: Any) {
            let custom_event = new CustomEvent(event, {
                bubbles: true,
                detail: detail
            });
            element.dispatchEvent(custom_event);
        }
    }
    
    # =========================================================================
    # ASYNC RENDERING
    # =========================================================================
    
    pub class AsyncRenderer {
        pub let renderer: DOMRenderer;
        pub let pending_update: Bool;
        pub let update_callback: fn()?;
        
        pub fn new(renderer: DOMRenderer) -> Self {
            return Self {
                renderer: renderer,
                pending_update: false,
                update_callback: null,
            };
        }
        
        # Schedule update (batches multiple updates)
        pub fn schedule_update(self, new_vdom: VNode) {
            if self.pending_update {
                return;
            }
            
            self.pending_update = true;
            
            # Use requestAnimationFrame for smooth updates
            requestAnimationFrame(fn() {
                self.renderer.update(new_vdom);
                self.pending_update = false;
                
                if self.update_callback != null {
                    self.update_callback();
                }
            });
        }
        
        # Set callback for after update
        pub fn on_update(self, callback: fn()) {
            self.update_callback = callback;
        }
        
        # Force immediate update
        pub fn flush(self, new_vdom: VNode) {
            self.renderer.update(new_vdom);
            self.pending_update = false;
        }
    }
    
    # =========================================================================
    # COMPONENT BASE
    # =========================================================================
    
    pub class Component {
        pub let props: Dict<String, Any>;
        pub let state: Dict<String, Any>;
        pub let mounted: Bool;
        pub let renderer: AsyncRenderer?;
        
        pub fn new() -> Self {
            return Self {
                props: {},
                state: {},
                mounted: false,
                renderer: null,
            };
        }
        
        # Lifecycle hooks
        pub fn on_mount(self) {}
        pub fn on_update(self) {}
        pub fn on_unmount(self) {}
        
        # Set state and trigger re-render
        pub fn set_state(self, key: String, value: Any) {
            self.state.set(key, value);
            self._trigger_update();
        }
        
        fn _trigger_update(self) {
            if self.renderer != null {
                self.renderer.schedule_update(self.render());
            }
        }
        
        # Override in subclass
        pub fn render(self) -> VNode {
            return VNode::new("div");
        }
        
        # Mount to DOM
        pub fn mount(self, container_id: String) {
            let renderer = DOMRenderer::new(container_id);
            renderer.render(self.render());
            self.renderer = AsyncRenderer::new(renderer);
            self.mounted = true;
            self.on_mount();
        }
        
        # Unmount from DOM
        pub fn unmount(self) {
            self.on_unmount();
            self.mounted = false;
        }
    }
    
    # =========================================================================
    # SSR + HYDRATION HELPERS
    # =========================================================================
    
    pub class SSRHydration {
        # Generate SSR HTML with hydration data
        pub fn render_with_hydration(component: Component, id: String) -> String {
            let vnode = component.render();
            let html = vnode.render_to_string();
            
            # Add hydration script
            let script = "<script>window.__NYX_HYDRATE__ = window.__NYX_HYDRATE__ || {};" +
                        "window.__NYX_HYDRATE__['" + id + "'] = " +
                        SSRHydration::serialize_vnode(vnode) + ";</script>";
            
            return html + script;
        }
        
        # Serialize VNode for client
        fn serialize_vnode(vnode: VNode) -> String {
            if vnode.tag == "#text" {
                return "{\"tag\":\"#text\",\"text\":\"" + vnode.text + "\"}";
            }
            
            let children_json = [];
            for child in vnode.children {
                children_json.push(SSRHydration::serialize_vnode(child));
            }
            
            return json.stringify({
                "tag": vnode.tag,
                "attrs": vnode.attrs,
                "children": children_json,
                "key": vnode.key
            });
        }
        
        # Deserialize VNode from client data
        pub fn deserialize(data: Dict<String, Any>) -> VNode {
            let tag = data.get("tag") as String;
            
            if tag == "#text" {
                return VNode::text(data.get("text") as String);
            }
            
            let vnode = VNode::new(tag);
            
            let attrs = data.get("attrs") as Dict<String, String>;
            for (name, value) in attrs {
                vnode.attr(name, value);
            }
            
            let children = data.get("children") as List<Dict<String, Any>>;
            for child_data in children {
                vnode.child(SSRHydration::deserialize(child_data));
            }
            
            let key = data.get("key");
            if key != null {
                vnode.key(key as String);
            }
            
            return vnode;
        }
    }
}

# Export advanced UI module
pub use nyui_advanced;