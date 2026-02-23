# ============================================================
# NYSTUDIO - Nyx Desktop Developer Tooling Engine
# ============================================================
# Production-grade developer tooling with visual GUI builder,
# live preview, drag-and-drop UI editor, performance profiler,
# memory debugger, hot reload, component inspector, and
# integrated design system tooling.

let VERSION = "1.0.0";

# ============================================================
# HOT RELOAD
# ============================================================

pub mod hot_reload {
    pub class FileWatcher {
        pub let id: Int;
        pub let watch_paths: List<String>;
        pub let extensions: List<String>;
        pub let debounce_ms: Int;
        pub let on_change: Fn?;
        pub let active: Bool;

        pub fn new() -> Self {
            return Self {
                id: 0,
                watch_paths: [],
                extensions: [".ny", ".css", ".json", ".toml"],
                debounce_ms: 100,
                on_change: null,
                active: false
            };
        }

        pub fn watch(self, path: String) -> Self {
            self.watch_paths.push(path);
            return self;
        }

        pub fn filter_extensions(self, exts: List<String>) -> Self {
            self.extensions = exts;
            return self;
        }

        pub fn on_file_change(self, callback: Fn) -> Self {
            self.on_change = callback;
            return self;
        }

        pub fn start(self) {
            self.id = native_studio_watch_start(self.watch_paths, self.extensions, self.debounce_ms, self.on_change);
            self.active = true;
        }

        pub fn stop(self) {
            native_studio_watch_stop(self.id);
            self.active = false;
        }
    }

    pub class HotReloadEngine {
        pub let watcher: FileWatcher;
        pub let reload_count: Int;
        pub let preserve_state: Bool;
        pub let on_before_reload: Fn?;
        pub let on_after_reload: Fn?;
        pub let error_overlay: Bool;

        pub fn new() -> Self {
            let engine = Self {
                watcher: FileWatcher::new(),
                reload_count: 0,
                preserve_state: true,
                on_before_reload: null,
                on_after_reload: null,
                error_overlay: true
            };

            engine.watcher.on_file_change(|change| {
                engine._handle_change(change);
            });

            return engine;
        }

        pub fn watch(self, path: String) -> Self {
            self.watcher.watch(path);
            return self;
        }

        pub fn start(self) {
            self.watcher.start();
        }

        pub fn stop(self) {
            self.watcher.stop();
        }

        fn _handle_change(self, change: Any) {
            if self.on_before_reload != null {
                self.on_before_reload(change);
            }

            let state_snapshot = null;
            if self.preserve_state {
                state_snapshot = native_studio_capture_state();
            }

            let result = native_studio_hot_reload(change.path);

            if result.success {
                self.reload_count = self.reload_count + 1;
                if self.preserve_state and state_snapshot != null {
                    native_studio_restore_state(state_snapshot);
                }
                if self.on_after_reload != null {
                    self.on_after_reload(change);
                }
            } else if self.error_overlay {
                native_studio_show_error_overlay(result.error);
            }
        }
    }
}

# ============================================================
# VISUAL GUI BUILDER
# ============================================================

pub mod gui_builder {
    pub class WidgetPalette {
        pub let categories: Map<String, List<WidgetTemplate>>;

        pub fn new() -> Self {
            let palette = Self { categories: {} };
            palette._register_defaults();
            return palette;
        }

        fn _register_defaults(self) {
            self.categories["Layout"] = [
                WidgetTemplate::new("Container", "layout", { "direction": "vertical" }),
                WidgetTemplate::new("Row", "layout", { "direction": "horizontal" }),
                WidgetTemplate::new("Column", "layout", { "direction": "vertical" }),
                WidgetTemplate::new("Grid", "layout", { "columns": 2 }),
                WidgetTemplate::new("Stack", "layout", { "alignment": "center" }),
                WidgetTemplate::new("ScrollView", "layout", { "direction": "vertical" }),
                WidgetTemplate::new("Tabs", "layout", { "position": "top" }),
                WidgetTemplate::new("Splitter", "layout", { "orientation": "horizontal" })
            ];

            self.categories["Input"] = [
                WidgetTemplate::new("Button", "input", { "text": "Button" }),
                WidgetTemplate::new("TextField", "input", { "placeholder": "" }),
                WidgetTemplate::new("TextArea", "input", { "rows": 4 }),
                WidgetTemplate::new("Checkbox", "input", { "checked": false }),
                WidgetTemplate::new("RadioGroup", "input", { "options": [] }),
                WidgetTemplate::new("Select", "input", { "options": [] }),
                WidgetTemplate::new("Slider", "input", { "min": 0, "max": 100 }),
                WidgetTemplate::new("Switch", "input", { "on": false }),
                WidgetTemplate::new("DatePicker", "input", {}),
                WidgetTemplate::new("ColorPicker", "input", { "color": "#000000" }),
                WidgetTemplate::new("FilePicker", "input", { "accept": "*" })
            ];

            self.categories["Display"] = [
                WidgetTemplate::new("Label", "display", { "text": "Label" }),
                WidgetTemplate::new("Image", "display", { "src": "" }),
                WidgetTemplate::new("Icon", "display", { "name": "star" }),
                WidgetTemplate::new("ProgressBar", "display", { "value": 0 }),
                WidgetTemplate::new("Spinner", "display", {}),
                WidgetTemplate::new("Badge", "display", { "count": 0 }),
                WidgetTemplate::new("Avatar", "display", { "src": "" }),
                WidgetTemplate::new("Tooltip", "display", { "text": "" })
            ];

            self.categories["Data"] = [
                WidgetTemplate::new("Table", "data", { "columns": [] }),
                WidgetTemplate::new("ListView", "data", { "items": [] }),
                WidgetTemplate::new("TreeView", "data", { "nodes": [] }),
                WidgetTemplate::new("Chart", "data", { "type": "bar" }),
                WidgetTemplate::new("DataGrid", "data", { "columns": [], "editable": false })
            ];

            self.categories["Navigation"] = [
                WidgetTemplate::new("MenuBar", "nav", {}),
                WidgetTemplate::new("Toolbar", "nav", {}),
                WidgetTemplate::new("Sidebar", "nav", { "width": 250 }),
                WidgetTemplate::new("Breadcrumb", "nav", { "items": [] }),
                WidgetTemplate::new("StatusBar", "nav", {})
            ];

            self.categories["Overlay"] = [
                WidgetTemplate::new("Dialog", "overlay", { "title": "Dialog" }),
                WidgetTemplate::new("Modal", "overlay", {}),
                WidgetTemplate::new("Popover", "overlay", {}),
                WidgetTemplate::new("ContextMenu", "overlay", { "items": [] }),
                WidgetTemplate::new("Toast", "overlay", { "message": "" })
            ];
        }

        pub fn add_category(self, name: String, templates: List<WidgetTemplate>) {
            self.categories[name] = templates;
        }

        pub fn all_widgets(self) -> List<WidgetTemplate> {
            let result = [];
            for entry in self.categories.entries() {
                for tmpl in entry.value {
                    result.push(tmpl);
                }
            }
            return result;
        }

        pub fn search(self, query: String) -> List<WidgetTemplate> {
            let q = query.to_lower();
            let results = [];
            for entry in self.categories.entries() {
                for tmpl in entry.value {
                    if tmpl.name.to_lower().contains(q) {
                        results.push(tmpl);
                    }
                }
            }
            return results;
        }
    }

    pub class WidgetTemplate {
        pub let name: String;
        pub let category: String;
        pub let default_props: Map<String, Any>;

        pub fn new(name: String, category: String, defaults: Map<String, Any>) -> Self {
            return Self { name: name, category: category, default_props: defaults };
        }
    }

    pub class CanvasElement {
        pub let id: String;
        pub let widget_type: String;
        pub let x: Float;
        pub let y: Float;
        pub let width: Float;
        pub let height: Float;
        pub let properties: Map<String, Any>;
        pub let children: List<CanvasElement>;
        pub let parent_id: String?;
        pub let selected: Bool;
        pub let locked: Bool;
        pub let visible: Bool;

        pub fn new(widget_type: String) -> Self {
            return Self {
                id: native_studio_uuid(),
                widget_type: widget_type,
                x: 0.0, y: 0.0,
                width: 100.0, height: 40.0,
                properties: {},
                children: [],
                parent_id: null,
                selected: false,
                locked: false,
                visible: true
            };
        }

        pub fn set_bounds(self, x: Float, y: Float, width: Float, height: Float) {
            self.x = x;
            self.y = y;
            self.width = width;
            self.height = height;
        }

        pub fn set_property(self, key: String, value: Any) {
            self.properties[key] = value;
        }

        pub fn add_child(self, child: CanvasElement) {
            child.parent_id = self.id;
            self.children.push(child);
        }

        pub fn remove_child(self, child_id: String) {
            self.children = self.children.filter(|c| c.id != child_id);
        }
    }

    pub class DesignCanvas {
        pub let root: CanvasElement;
        pub let selection: List<String>;
        pub let zoom: Float;
        pub let pan_x: Float;
        pub let pan_y: Float;
        pub let grid_size: Int;
        pub let snap_to_grid: Bool;
        pub let show_guides: Bool;
        pub let undo_stack: List<String>;
        pub let redo_stack: List<String>;

        pub fn new() -> Self {
            return Self {
                root: CanvasElement::new("Root"),
                selection: [],
                zoom: 1.0,
                pan_x: 0.0,
                pan_y: 0.0,
                grid_size: 8,
                snap_to_grid: true,
                show_guides: true,
                undo_stack: [],
                redo_stack: []
            };
        }

        pub fn add_element(self, element: CanvasElement, parent_id: String?) {
            self._save_undo();
            if parent_id == null {
                self.root.add_child(element);
            } else {
                let parent = self._find_element(self.root, parent_id);
                if parent != null {
                    parent.add_child(element);
                }
            }
        }

        pub fn remove_element(self, element_id: String) {
            self._save_undo();
            self._remove_recursive(self.root, element_id);
        }

        pub fn select(self, element_id: String) {
            self.selection = [element_id];
            let elem = self._find_element(self.root, element_id);
            if elem != null {
                elem.selected = true;
            }
        }

        pub fn multi_select(self, ids: List<String>) {
            self.selection = ids;
        }

        pub fn deselect_all(self) {
            self.selection = [];
        }

        pub fn move_element(self, id: String, dx: Float, dy: Float) {
            let elem = self._find_element(self.root, id);
            if elem == null or elem.locked { return; }
            elem.x = elem.x + dx;
            elem.y = elem.y + dy;
            if self.snap_to_grid {
                elem.x = (elem.x / self.grid_size as Float).round() * self.grid_size as Float;
                elem.y = (elem.y / self.grid_size as Float).round() * self.grid_size as Float;
            }
        }

        pub fn resize_element(self, id: String, width: Float, height: Float) {
            let elem = self._find_element(self.root, id);
            if elem == null or elem.locked { return; }
            elem.width = width;
            elem.height = height;
        }

        pub fn undo(self) -> Bool {
            if self.undo_stack.len() == 0 { return false; }
            self.redo_stack.push(self._serialize());
            let state = self.undo_stack.pop();
            self._deserialize(state);
            return true;
        }

        pub fn redo(self) -> Bool {
            if self.redo_stack.len() == 0 { return false; }
            self.undo_stack.push(self._serialize());
            let state = self.redo_stack.pop();
            self._deserialize(state);
            return true;
        }

        fn _save_undo(self) {
            self.undo_stack.push(self._serialize());
            self.redo_stack = [];
        }

        fn _find_element(self, root: CanvasElement, id: String) -> CanvasElement? {
            if root.id == id { return root; }
            for child in root.children {
                let found = self._find_element(child, id);
                if found != null { return found; }
            }
            return null;
        }

        fn _remove_recursive(self, root: CanvasElement, id: String) {
            root.children = root.children.filter(|c| c.id != id);
            for child in root.children {
                self._remove_recursive(child, id);
            }
        }

        fn _serialize(self) -> String {
            return native_studio_serialize_canvas(self.root);
        }

        fn _deserialize(self, data: String) {
            self.root = native_studio_deserialize_canvas(data);
        }

        pub fn export_code(self) -> String {
            return native_studio_canvas_to_code(self.root);
        }

        pub fn export_layout(self) -> String {
            return native_studio_canvas_to_layout(self.root);
        }
    }
}

# ============================================================
# LIVE PREVIEW
# ============================================================

pub mod preview {
    pub class PreviewConfig {
        pub let auto_refresh: Bool;
        pub let responsive_mode: Bool;
        pub let viewports: List<Viewport>;
        pub let show_bounds: Bool;
        pub let show_spacing: Bool;

        pub fn new() -> Self {
            return Self {
                auto_refresh: true,
                responsive_mode: false,
                viewports: [
                    Viewport::new("Desktop", 1920, 1080),
                    Viewport::new("Laptop", 1366, 768),
                    Viewport::new("Tablet", 768, 1024),
                    Viewport::new("Phone", 375, 812)
                ],
                show_bounds: false,
                show_spacing: false
            };
        }
    }

    pub class Viewport {
        pub let name: String;
        pub let width: Int;
        pub let height: Int;

        pub fn new(name: String, width: Int, height: Int) -> Self {
            return Self { name: name, width: width, height: height };
        }
    }

    pub class LivePreview {
        pub let config: PreviewConfig;
        pub let current_viewport: Viewport;
        pub let running: Bool;
        pub let render_handle: Int?;

        pub fn new() -> Self {
            let config = PreviewConfig::new();
            return Self {
                config: config,
                current_viewport: config.viewports[0],
                running: false,
                render_handle: null
            };
        }

        pub fn start(self, source: String) {
            self.render_handle = native_studio_preview_start(source, self.current_viewport);
            self.running = true;
        }

        pub fn refresh(self, source: String) {
            if self.render_handle != null {
                native_studio_preview_update(self.render_handle, source);
            }
        }

        pub fn set_viewport(self, viewport: Viewport) {
            self.current_viewport = viewport;
            if self.render_handle != null {
                native_studio_preview_resize(self.render_handle, viewport.width, viewport.height);
            }
        }

        pub fn toggle_bounds(self) {
            self.config.show_bounds = not self.config.show_bounds;
            native_studio_preview_set_overlay(self.render_handle, "bounds", self.config.show_bounds);
        }

        pub fn toggle_spacing(self) {
            self.config.show_spacing = not self.config.show_spacing;
            native_studio_preview_set_overlay(self.render_handle, "spacing", self.config.show_spacing);
        }

        pub fn stop(self) {
            if self.render_handle != null {
                native_studio_preview_stop(self.render_handle);
            }
            self.running = false;
        }

        pub fn screenshot(self) -> Bytes {
            return native_studio_preview_screenshot(self.render_handle);
        }
    }
}

# ============================================================
# COMPONENT INSPECTOR
# ============================================================

pub mod inspector {
    pub class PropertyEditor {
        pub let target_id: String;
        pub let properties: List<PropertyDef>;

        pub fn new(target_id: String) -> Self {
            return Self { target_id: target_id, properties: [] };
        }

        pub fn inspect(self, element: Any) {
            self.properties = native_studio_inspect_properties(element);
        }

        pub fn set_property(self, name: String, value: Any) {
            native_studio_set_element_property(self.target_id, name, value);
        }

        pub fn get_property(self, name: String) -> Any? {
            for prop in self.properties {
                if prop.name == name { return prop.value; }
            }
            return null;
        }
    }

    pub class PropertyDef {
        pub let name: String;
        pub let type_name: String;
        pub let value: Any;
        pub let editable: Bool;
        pub let options: List<Any>?;
        pub let min: Float?;
        pub let max: Float?;
        pub let group: String;
    }

    pub class TreeInspector {
        pub let root: TreeNode?;

        pub fn new() -> Self {
            return Self { root: null };
        }

        pub fn build(self, element: Any) {
            self.root = native_studio_build_tree(element);
        }

        pub fn find_by_id(self, id: String) -> TreeNode? {
            if self.root == null { return null; }
            return self._search(self.root, id);
        }

        fn _search(self, node: TreeNode, id: String) -> TreeNode? {
            if node.id == id { return node; }
            for child in node.children {
                let found = self._search(child, id);
                if found != null { return found; }
            }
            return null;
        }

        pub fn highlight(self, id: String) {
            native_studio_highlight_element(id);
        }

        pub fn clear_highlight(self) {
            native_studio_clear_highlight();
        }
    }

    pub class TreeNode {
        pub let id: String;
        pub let type_name: String;
        pub let label: String;
        pub let children: List<TreeNode>;
        pub let expanded: Bool;
        pub let visible: Bool;
    }

    pub class StyleInspector {
        pub fn computed_styles(element_id: String) -> Map<String, Any> {
            return native_studio_computed_styles(element_id);
        }

        pub fn applied_rules(element_id: String) -> List<Map<String, Any>> {
            return native_studio_applied_rules(element_id);
        }

        pub fn box_model(element_id: String) -> Map<String, Float> {
            return native_studio_box_model(element_id);
        }
    }
}

# ============================================================
# PERFORMANCE PROFILER
# ============================================================

pub mod profiler {
    pub class FrameProfile {
        pub let frame_id: Int;
        pub let total_ms: Float;
        pub let layout_ms: Float;
        pub let paint_ms: Float;
        pub let script_ms: Float;
        pub let gpu_ms: Float;
        pub let idle_ms: Float;
        pub let gc_ms: Float;

        pub fn is_jank(self) -> Bool {
            return self.total_ms > 16.67;
        }
    }

    pub class Profiler {
        pub let recording: Bool;
        pub let frames: List<FrameProfile>;
        pub let marks: Map<String, Float>;
        pub let measures: Map<String, Float>;
        pub let max_frames: Int;

        pub fn new() -> Self {
            return Self {
                recording: false,
                frames: [],
                marks: {},
                measures: {},
                max_frames: 600
            };
        }

        pub fn start(self) {
            self.recording = true;
            self.frames = [];
            native_studio_profiler_start();
        }

        pub fn stop(self) -> List<FrameProfile> {
            self.recording = false;
            native_studio_profiler_stop();
            return self.frames;
        }

        pub fn mark(self, name: String) {
            self.marks[name] = native_studio_time_precise();
        }

        pub fn measure(self, name: String, start_mark: String, end_mark: String) -> Float {
            let start = self.marks[start_mark] or 0.0;
            let end = self.marks[end_mark] or 0.0;
            let duration = end - start;
            self.measures[name] = duration;
            return duration;
        }

        pub fn record_frame(self, profile: FrameProfile) {
            if not self.recording { return; }
            self.frames.push(profile);
            if self.frames.len() > self.max_frames {
                self.frames.remove(0);
            }
        }

        pub fn average_fps(self) -> Float {
            if self.frames.len() == 0 { return 0.0; }
            let total = 0.0;
            for f in self.frames {
                total = total + f.total_ms;
            }
            let avg_ms = total / self.frames.len() as Float;
            return 1000.0 / avg_ms;
        }

        pub fn percentile(self, p: Float) -> Float {
            if self.frames.len() == 0 { return 0.0; }
            let sorted = self.frames.map(|f| f.total_ms);
            sorted.sort(|a, b| a - b);
            let idx = ((p / 100.0) * sorted.len() as Float) as Int;
            if idx >= sorted.len() { idx = sorted.len() - 1; }
            return sorted[idx];
        }

        pub fn jank_count(self) -> Int {
            let count = 0;
            for f in self.frames {
                if f.is_jank() { count = count + 1; }
            }
            return count;
        }

        pub fn report(self) -> Map<String, Any> {
            return {
                "frame_count": self.frames.len(),
                "avg_fps": self.average_fps(),
                "p50_ms": self.percentile(50.0),
                "p95_ms": self.percentile(95.0),
                "p99_ms": self.percentile(99.0),
                "jank_frames": self.jank_count(),
                "measures": self.measures
            };
        }

        pub fn export_trace(self) -> String {
            return native_studio_export_trace(self.frames);
        }
    }

    pub class CPUProfiler {
        pub let samples: List<Map<String, Any>>;
        pub let sampling_interval_ms: Int;

        pub fn new() -> Self {
            return Self { samples: [], sampling_interval_ms: 1 };
        }

        pub fn start(self) {
            native_studio_cpu_profile_start(self.sampling_interval_ms);
        }

        pub fn stop(self) -> List<Map<String, Any>> {
            self.samples = native_studio_cpu_profile_stop();
            return self.samples;
        }

        pub fn flame_graph(self) -> String {
            return native_studio_generate_flame_graph(self.samples);
        }

        pub fn hotspots(self, top_n: Int) -> List<Map<String, Any>> {
            return native_studio_cpu_hotspots(self.samples, top_n);
        }
    }
}

# ============================================================
# MEMORY DEBUGGER
# ============================================================

pub mod memory_debug {
    pub class AllocationEntry {
        pub let address: Int;
        pub let size_bytes: Int;
        pub let type_name: String;
        pub let stack_trace: String;
        pub let timestamp_ms: Int;
        pub let freed: Bool;
    }

    pub class MemoryDebugger {
        pub let tracking: Bool;
        pub let allocations: List<AllocationEntry>;
        pub let snapshots: List<MemorySnapshot>;

        pub fn new() -> Self {
            return Self { tracking: false, allocations: [], snapshots: [] };
        }

        pub fn start_tracking(self) {
            self.tracking = true;
            native_studio_memory_track_start();
        }

        pub fn stop_tracking(self) {
            self.tracking = false;
            native_studio_memory_track_stop();
        }

        pub fn take_snapshot(self, label: String) -> MemorySnapshot {
            let snap = MemorySnapshot {
                label: label,
                timestamp_ms: native_studio_time_ms(),
                total_bytes: native_studio_memory_total(),
                allocation_count: native_studio_memory_alloc_count(),
                type_breakdown: native_studio_memory_by_type(),
                largest_objects: native_studio_memory_largest(20)
            };
            self.snapshots.push(snap);
            return snap;
        }

        pub fn diff(self, snap_a: MemorySnapshot, snap_b: MemorySnapshot) -> MemoryDiff {
            return MemoryDiff {
                bytes_delta: snap_b.total_bytes - snap_a.total_bytes,
                alloc_delta: snap_b.allocation_count - snap_a.allocation_count,
                type_changes: native_studio_memory_diff_types(snap_a, snap_b),
                new_allocations: native_studio_memory_diff_allocs(snap_a, snap_b)
            };
        }

        pub fn detect_leaks(self) -> List<AllocationEntry> {
            return native_studio_memory_detect_leaks();
        }

        pub fn gc_stats(self) -> Map<String, Any> {
            return native_studio_gc_stats();
        }

        pub fn heap_dump(self, path: String) {
            native_studio_heap_dump(path);
        }
    }

    pub class MemorySnapshot {
        pub let label: String;
        pub let timestamp_ms: Int;
        pub let total_bytes: Int;
        pub let allocation_count: Int;
        pub let type_breakdown: Map<String, Int>;
        pub let largest_objects: List<AllocationEntry>;
    }

    pub class MemoryDiff {
        pub let bytes_delta: Int;
        pub let alloc_delta: Int;
        pub let type_changes: Map<String, Int>;
        pub let new_allocations: List<AllocationEntry>;
    }
}

# ============================================================
# DESIGN SYSTEM
# ============================================================

pub mod design_system {
    pub class ColorToken {
        pub let name: String;
        pub let light: String;
        pub let dark: String;

        pub fn new(name: String, light: String, dark: String) -> Self {
            return Self { name: name, light: light, dark: dark };
        }
    }

    pub class TypographyToken {
        pub let name: String;
        pub let font_family: String;
        pub let font_size: Float;
        pub let font_weight: Int;
        pub let line_height: Float;
        pub let letter_spacing: Float;

        pub fn new(name: String, family: String, size: Float, weight: Int) -> Self {
            return Self {
                name: name,
                font_family: family,
                font_size: size,
                font_weight: weight,
                line_height: size * 1.5,
                letter_spacing: 0.0
            };
        }
    }

    pub class SpacingToken {
        pub let name: String;
        pub let value: Float;

        pub fn new(name: String, value: Float) -> Self {
            return Self { name: name, value: value };
        }
    }

    pub class DesignTokens {
        pub let colors: Map<String, ColorToken>;
        pub let typography: Map<String, TypographyToken>;
        pub let spacing: Map<String, SpacingToken>;
        pub let radii: Map<String, Float>;
        pub let shadows: Map<String, String>;
        pub let breakpoints: Map<String, Int>;

        pub fn new() -> Self {
            return Self {
                colors: {},
                typography: {},
                spacing: {},
                radii: {},
                shadows: {},
                breakpoints: {}
            };
        }

        pub fn add_color(self, token: ColorToken) {
            self.colors[token.name] = token;
        }

        pub fn add_typography(self, token: TypographyToken) {
            self.typography[token.name] = token;
        }

        pub fn add_spacing(self, token: SpacingToken) {
            self.spacing[token.name] = token;
        }

        pub fn export_css(self) -> String {
            return native_studio_tokens_to_css(self);
        }

        pub fn export_json(self) -> String {
            return native_studio_tokens_to_json(self);
        }

        pub fn import_figma(self, json: String) {
            native_studio_import_figma_tokens(self, json);
        }
    }
}

# ============================================================
# CODE GENERATION
# ============================================================

pub mod codegen {
    pub class CodeGenerator {
        pub let indent: String;
        pub let style: String;

        pub fn new() -> Self {
            return Self { indent: "    ", style: "declarative" };
        }

        pub fn from_canvas(self, canvas: gui_builder.DesignCanvas) -> String {
            return native_studio_generate_code(canvas.root, self.style, self.indent);
        }

        pub fn from_element(self, element: gui_builder.CanvasElement) -> String {
            return native_studio_generate_code(element, self.style, self.indent);
        }

        pub fn component_scaffold(self, name: String, props: List<String>) -> String {
            let code = "pub class " + name + " {\n";
            for prop in props {
                code = code + self.indent + "pub let " + prop + ": Any;\n";
            }
            code = code + "\n" + self.indent + "pub fn new() -> Self {\n";
            code = code + self.indent + self.indent + "return Self {\n";
            for prop in props {
                code = code + self.indent + self.indent + self.indent + prop + ": null\n";
            }
            code = code + self.indent + self.indent + "};\n";
            code = code + self.indent + "}\n\n";
            code = code + self.indent + "pub fn render(self) -> Widget {\n";
            code = code + self.indent + self.indent + "# TODO: implement render\n";
            code = code + self.indent + "}\n";
            code = code + "}\n";
            return code;
        }
    }
}

# ============================================================
# ACCESSIBILITY CHECKER
# ============================================================

pub mod accessibility {
    pub class AccessibilityIssue {
        pub let element_id: String;
        pub let severity: String;
        pub let rule: String;
        pub let message: String;
        pub let suggestion: String;
    }

    pub class AccessibilityChecker {
        pub fn audit(element: Any) -> List<AccessibilityIssue> {
            return native_studio_a11y_audit(element);
        }

        pub fn check_contrast(foreground: String, background: String) -> Map<String, Any> {
            return native_studio_a11y_contrast(foreground, background);
        }

        pub fn check_focus_order(root: Any) -> List<String> {
            return native_studio_a11y_focus_order(root);
        }

        pub fn check_aria_labels(root: Any) -> List<AccessibilityIssue> {
            return native_studio_a11y_aria_check(root);
        }

        pub fn report(root: Any) -> Map<String, Any> {
            let issues = Self::audit(root);
            let errors = issues.filter(|i| i.severity == "error");
            let warnings = issues.filter(|i| i.severity == "warning");
            return {
                "total_issues": issues.len(),
                "errors": errors.len(),
                "warnings": warnings.len(),
                "issues": issues,
                "score": ((1.0 - errors.len() as Float / (issues.len() as Float + 1.0)) * 100.0) as Int
            };
        }
    }
}

# ============================================================
# STUDIO ORCHESTRATOR
# ============================================================

pub class Studio {
    pub let hot_reload: hot_reload.HotReloadEngine;
    pub let palette: gui_builder.WidgetPalette;
    pub let canvas: gui_builder.DesignCanvas;
    pub let preview_engine: preview.LivePreview;
    pub let tree_inspector: inspector.TreeInspector;
    pub let style_inspector: inspector.StyleInspector;
    pub let perf_profiler: profiler.Profiler;
    pub let cpu_profiler: profiler.CPUProfiler;
    pub let memory_debugger: memory_debug.MemoryDebugger;
    pub let design_tokens: design_system.DesignTokens;
    pub let code_gen: codegen.CodeGenerator;
    pub let a11y_checker: accessibility.AccessibilityChecker;

    pub fn new() -> Self {
        return Self {
            hot_reload: hot_reload.HotReloadEngine::new(),
            palette: gui_builder.WidgetPalette::new(),
            canvas: gui_builder.DesignCanvas::new(),
            preview_engine: preview.LivePreview::new(),
            tree_inspector: inspector.TreeInspector::new(),
            style_inspector: inspector.StyleInspector(),
            perf_profiler: profiler.Profiler::new(),
            cpu_profiler: profiler.CPUProfiler::new(),
            memory_debugger: memory_debug.MemoryDebugger::new(),
            design_tokens: design_system.DesignTokens::new(),
            code_gen: codegen.CodeGenerator::new(),
            a11y_checker: accessibility.AccessibilityChecker()
        };
    }

    pub fn start_dev_mode(self, project_path: String) {
        self.hot_reload.watch(project_path).start();
        self.perf_profiler.start();
    }

    pub fn stop_dev_mode(self) {
        self.hot_reload.stop();
        self.perf_profiler.stop();
    }

    pub fn generate_code(self) -> String {
        return self.code_gen.from_canvas(self.canvas);
    }

    pub fn run_a11y_audit(self) -> Map<String, Any> {
        return self.a11y_checker.report(self.canvas.root);
    }

    pub fn performance_report(self) -> Map<String, Any> {
        return self.perf_profiler.report();
    }

    pub fn memory_snapshot(self, label: String) -> memory_debug.MemorySnapshot {
        return self.memory_debugger.take_snapshot(label);
    }
}

pub fn create_studio() -> Studio {
    return Studio::new();
}

# ============================================================
# NATIVE HOOKS
# ============================================================

# File watching & hot reload
native_studio_watch_start(paths: List, exts: List, debounce: Int, callback: Fn) -> Int;
native_studio_watch_stop(id: Int);
native_studio_hot_reload(path: String) -> Any;
native_studio_capture_state() -> Any;
native_studio_restore_state(state: Any);
native_studio_show_error_overlay(error: Any);

# Canvas & GUI builder
native_studio_uuid() -> String;
native_studio_serialize_canvas(root: Any) -> String;
native_studio_deserialize_canvas(data: String) -> Any;
native_studio_canvas_to_code(root: Any) -> String;
native_studio_canvas_to_layout(root: Any) -> String;
native_studio_generate_code(element: Any, style: String, indent: String) -> String;

# Preview
native_studio_preview_start(source: String, viewport: Any) -> Int;
native_studio_preview_update(handle: Int, source: String);
native_studio_preview_resize(handle: Int, width: Int, height: Int);
native_studio_preview_set_overlay(handle: Int, overlay: String, enabled: Bool);
native_studio_preview_stop(handle: Int);
native_studio_preview_screenshot(handle: Int) -> Bytes;

# Inspector
native_studio_inspect_properties(element: Any) -> List;
native_studio_set_element_property(id: String, name: String, value: Any);
native_studio_build_tree(element: Any) -> Any;
native_studio_highlight_element(id: String);
native_studio_clear_highlight();
native_studio_computed_styles(id: String) -> Map;
native_studio_applied_rules(id: String) -> List;
native_studio_box_model(id: String) -> Map;

# Profiler
native_studio_profiler_start();
native_studio_profiler_stop();
native_studio_time_precise() -> Float;
native_studio_time_ms() -> Int;
native_studio_export_trace(frames: List) -> String;
native_studio_cpu_profile_start(interval: Int);
native_studio_cpu_profile_stop() -> List;
native_studio_generate_flame_graph(samples: List) -> String;
native_studio_cpu_hotspots(samples: List, top_n: Int) -> List;

# Memory debugger
native_studio_memory_track_start();
native_studio_memory_track_stop();
native_studio_memory_total() -> Int;
native_studio_memory_alloc_count() -> Int;
native_studio_memory_by_type() -> Map;
native_studio_memory_largest(count: Int) -> List;
native_studio_memory_diff_types(a: Any, b: Any) -> Map;
native_studio_memory_diff_allocs(a: Any, b: Any) -> List;
native_studio_memory_detect_leaks() -> List;
native_studio_gc_stats() -> Map;
native_studio_heap_dump(path: String);

# Design system
native_studio_tokens_to_css(tokens: Any) -> String;
native_studio_tokens_to_json(tokens: Any) -> String;
native_studio_import_figma_tokens(tokens: Any, json: String);

# Accessibility
native_studio_a11y_audit(element: Any) -> List;
native_studio_a11y_contrast(fg: String, bg: String) -> Map;
native_studio_a11y_focus_order(root: Any) -> List;
native_studio_a11y_aria_check(root: Any) -> List;

# ============================================================
# PRODUCTION-READY INFRASTRUCTURE
# ============================================================

pub mod production {

    pub class HealthStatus {
        pub let status: String;
        pub let uptime_ms: Int;
        pub let checks: Map;
        pub let version: String;

        pub fn new() -> Self {
            return Self {
                status: "healthy",
                uptime_ms: 0,
                checks: {},
                version: VERSION
            };
        }

        pub fn is_healthy(self) -> Bool {
            return self.status == "healthy";
        }

        pub fn add_check(self, name: String, passed: Bool, detail: String) {
            self.checks[name] = { "passed": passed, "detail": detail };
            if !passed { self.status = "degraded"; }
        }
    }

    pub class MetricsCollector {
        pub let counters: Map;
        pub let gauges: Map;
        pub let histograms: Map;
        pub let start_time: Int;

        pub fn new() -> Self {
            return Self {
                counters: {},
                gauges: {},
                histograms: {},
                start_time: native_production_time_ms()
            };
        }

        pub fn increment(self, name: String, value: Int) {
            self.counters[name] = (self.counters[name] or 0) + value;
        }

        pub fn gauge_set(self, name: String, value: Float) {
            self.gauges[name] = value;
        }

        pub fn histogram_observe(self, name: String, value: Float) {
            if self.histograms[name] == null { self.histograms[name] = []; }
            self.histograms[name].push(value);
        }

        pub fn snapshot(self) -> Map {
            return {
                "counters": self.counters,
                "gauges": self.gauges,
                "uptime_ms": native_production_time_ms() - self.start_time
            };
        }

        pub fn reset(self) {
            self.counters = {};
            self.gauges = {};
            self.histograms = {};
        }
    }

    pub class Logger {
        pub let level: String;
        pub let buffer: List;
        pub let max_buffer: Int;

        pub fn new(level: String) -> Self {
            return Self { level: level, buffer: [], max_buffer: 10000 };
        }

        pub fn debug(self, msg: String, context: Map?) {
            if self.level == "debug" { self._log("DEBUG", msg, context); }
        }

        pub fn info(self, msg: String, context: Map?) {
            if self.level != "error" and self.level != "warn" {
                self._log("INFO", msg, context);
            }
        }

        pub fn warn(self, msg: String, context: Map?) {
            if self.level != "error" { self._log("WARN", msg, context); }
        }

        pub fn error(self, msg: String, context: Map?) {
            self._log("ERROR", msg, context);
        }

        fn _log(self, lvl: String, msg: String, context: Map?) {
            let entry = {
                "ts": native_production_time_ms(),
                "level": lvl,
                "msg": msg,
                "ctx": context
            };
            self.buffer.push(entry);
            if self.buffer.len() > self.max_buffer {
                self.buffer = self.buffer[self.max_buffer / 2..];
            }
        }

        pub fn flush(self) -> List {
            let out = self.buffer;
            self.buffer = [];
            return out;
        }
    }

    pub class CircuitBreaker {
        pub let state: String;
        pub let failure_count: Int;
        pub let threshold: Int;
        pub let reset_timeout_ms: Int;
        pub let last_failure_time: Int;

        pub fn new(threshold: Int, reset_timeout_ms: Int) -> Self {
            return Self {
                state: "closed",
                failure_count: 0,
                threshold: threshold,
                reset_timeout_ms: reset_timeout_ms,
                last_failure_time: 0
            };
        }

        pub fn allow_request(self) -> Bool {
            if self.state == "closed" { return true; }
            if self.state == "open" {
                let elapsed = native_production_time_ms() - self.last_failure_time;
                if elapsed >= self.reset_timeout_ms {
                    self.state = "half-open";
                    return true;
                }
                return false;
            }
            return true;
        }

        pub fn record_success(self) {
            self.failure_count = 0;
            self.state = "closed";
        }

        pub fn record_failure(self) {
            self.failure_count = self.failure_count + 1;
            self.last_failure_time = native_production_time_ms();
            if self.failure_count >= self.threshold {
                self.state = "open";
            }
        }
    }

    pub class RetryPolicy {
        pub let max_retries: Int;
        pub let base_delay_ms: Int;
        pub let max_delay_ms: Int;
        pub let backoff_multiplier: Float;

        pub fn new(max_retries: Int) -> Self {
            return Self {
                max_retries: max_retries,
                base_delay_ms: 100,
                max_delay_ms: 30000,
                backoff_multiplier: 2.0
            };
        }

        pub fn get_delay(self, attempt: Int) -> Int {
            let delay = self.base_delay_ms;
            for _ in 0..attempt { delay = (delay * self.backoff_multiplier).to_int(); }
            if delay > self.max_delay_ms { delay = self.max_delay_ms; }
            return delay;
        }
    }

    pub class RateLimiter {
        pub let max_requests: Int;
        pub let window_ms: Int;
        pub let requests: List;

        pub fn new(max_requests: Int, window_ms: Int) -> Self {
            return Self { max_requests: max_requests, window_ms: window_ms, requests: [] };
        }

        pub fn allow(self) -> Bool {
            let now = native_production_time_ms();
            self.requests = self.requests.filter(fn(t) { t > now - self.window_ms });
            if self.requests.len() >= self.max_requests { return false; }
            self.requests.push(now);
            return true;
        }
    }

    pub class GracefulShutdown {
        pub let hooks: List;
        pub let timeout_ms: Int;
        pub let is_shutting_down: Bool;

        pub fn new(timeout_ms: Int) -> Self {
            return Self { hooks: [], timeout_ms: timeout_ms, is_shutting_down: false };
        }

        pub fn register(self, name: String, hook: Fn) {
            self.hooks.push({ "name": name, "hook": hook });
        }

        pub fn shutdown(self) {
            self.is_shutting_down = true;
            for entry in self.hooks {
                entry.hook();
            }
        }
    }

    pub class ProductionRuntime {
        pub let health: HealthStatus;
        pub let metrics: MetricsCollector;
        pub let logger: Logger;
        pub let circuit_breaker: CircuitBreaker;
        pub let rate_limiter: RateLimiter;
        pub let shutdown: GracefulShutdown;

        pub fn new() -> Self {
            return Self {
                health: HealthStatus::new(),
                metrics: MetricsCollector::new(),
                logger: Logger::new("info"),
                circuit_breaker: CircuitBreaker::new(5, 30000),
                rate_limiter: RateLimiter::new(1000, 60000),
                shutdown: GracefulShutdown::new(30000)
            };
        }

        pub fn check_health(self) -> HealthStatus {
            self.health.uptime_ms = native_production_time_ms() - self.metrics.start_time;
            return self.health;
        }

        pub fn get_metrics(self) -> Map {
            return self.metrics.snapshot();
        }

        pub fn is_ready(self) -> Bool {
            return self.health.is_healthy() and !self.shutdown.is_shutting_down;
        }
    }
}

native_production_time_ms() -> Int;

# ============================================================
# OBSERVABILITY & ERROR HANDLING
# ============================================================

pub mod observability {

    pub class Span {
        pub let trace_id: String;
        pub let span_id: String;
        pub let parent_id: String?;
        pub let operation: String;
        pub let start_time: Int;
        pub let end_time: Int?;
        pub let tags: Map;
        pub let status: String;

        pub fn new(operation: String, parent_id: String?) -> Self {
            return Self {
                trace_id: native_production_time_ms().to_string(),
                span_id: native_production_time_ms().to_string(),
                parent_id: parent_id,
                operation: operation,
                start_time: native_production_time_ms(),
                end_time: null,
                tags: {},
                status: "ok"
            };
        }

        pub fn set_tag(self, key: String, value: String) {
            self.tags[key] = value;
        }

        pub fn finish(self) {
            self.end_time = native_production_time_ms();
        }

        pub fn finish_with_error(self, error: String) {
            self.end_time = native_production_time_ms();
            self.status = "error";
            self.tags["error"] = error;
        }

        pub fn duration_ms(self) -> Int {
            if self.end_time == null { return 0; }
            return self.end_time - self.start_time;
        }
    }

    pub class Tracer {
        pub let spans: List;
        pub let active_span: Span?;
        pub let service_name: String;

        pub fn new(service_name: String) -> Self {
            return Self { spans: [], active_span: null, service_name: service_name };
        }

        pub fn start_span(self, operation: String) -> Span {
            let parent = if self.active_span != null { self.active_span.span_id } else { null };
            let span = Span::new(operation, parent);
            span.set_tag("service", self.service_name);
            self.active_span = span;
            return span;
        }

        pub fn finish_span(self, span: Span) {
            span.finish();
            self.spans.push(span);
            self.active_span = null;
        }

        pub fn get_traces(self) -> List {
            return self.spans;
        }
    }

    pub class AlertRule {
        pub let name: String;
        pub let condition: Fn;
        pub let severity: String;
        pub let cooldown_ms: Int;
        pub let last_fired: Int;

        pub fn new(name: String, condition: Fn, severity: String) -> Self {
            return Self {
                name: name,
                condition: condition,
                severity: severity,
                cooldown_ms: 60000,
                last_fired: 0
            };
        }

        pub fn evaluate(self, metrics: Map) -> Bool {
            let now = native_production_time_ms();
            if now - self.last_fired < self.cooldown_ms { return false; }
            if self.condition(metrics) {
                self.last_fired = now;
                return true;
            }
            return false;
        }
    }

    pub class AlertManager {
        pub let rules: List;
        pub let alerts: List;

        pub fn new() -> Self {
            return Self { rules: [], alerts: [] };
        }

        pub fn add_rule(self, rule: AlertRule) {
            self.rules.push(rule);
        }

        pub fn evaluate_all(self, metrics: Map) -> List {
            let fired = [];
            for rule in self.rules {
                if rule.evaluate(metrics) {
                    let alert = {
                        "name": rule.name,
                        "severity": rule.severity,
                        "time": native_production_time_ms()
                    };
                    self.alerts.push(alert);
                    fired.push(alert);
                }
            }
            return fired;
        }
    }
}

pub mod error_handling {

    pub class EngineError {
        pub let code: String;
        pub let message: String;
        pub let context: Map;
        pub let timestamp: Int;
        pub let recoverable: Bool;

        pub fn new(code: String, message: String, recoverable: Bool) -> Self {
            return Self {
                code: code,
                message: message,
                context: {},
                timestamp: native_production_time_ms(),
                recoverable: recoverable
            };
        }

        pub fn with_context(self, key: String, value: Any) -> Self {
            self.context[key] = value;
            return self;
        }
    }

    pub class ErrorRegistry {
        pub let errors: List;
        pub let max_errors: Int;

        pub fn new(max_errors: Int) -> Self {
            return Self { errors: [], max_errors: max_errors };
        }

        pub fn record(self, error: EngineError) {
            self.errors.push(error);
            if self.errors.len() > self.max_errors {
                self.errors = self.errors[self.errors.len() - self.max_errors..];
            }
        }

        pub fn get_recent(self, count: Int) -> List {
            let start = if self.errors.len() > count { self.errors.len() - count } else { 0 };
            return self.errors[start..];
        }

        pub fn count_by_code(self, code: String) -> Int {
            return self.errors.filter(fn(e) { e.code == code }).len();
        }
    }

    pub class RecoveryStrategy {
        pub let name: String;
        pub let max_attempts: Int;
        pub let handler: Fn;

        pub fn new(name: String, max_attempts: Int, handler: Fn) -> Self {
            return Self { name: name, max_attempts: max_attempts, handler: handler };
        }
    }

    pub class ErrorHandler {
        pub let registry: ErrorRegistry;
        pub let strategies: Map;
        pub let fallback: Fn?;

        pub fn new() -> Self {
            return Self {
                registry: ErrorRegistry::new(1000),
                strategies: {},
                fallback: null
            };
        }

        pub fn register_strategy(self, code: String, strategy: RecoveryStrategy) {
            self.strategies[code] = strategy;
        }

        pub fn set_fallback(self, handler: Fn) {
            self.fallback = handler;
        }

        pub fn handle(self, error: EngineError) -> Any? {
            self.registry.record(error);
            if error.recoverable and self.strategies[error.code] != null {
                let strategy = self.strategies[error.code];
                return strategy.handler(error);
            }
            if self.fallback != null { return self.fallback(error); }
            return null;
        }
    }
}

# ============================================================
# CONFIGURATION & LIFECYCLE MANAGEMENT
# ============================================================

pub mod config_management {

    pub class EnvConfig {
        pub let values: Map;
        pub let defaults: Map;
        pub let required_keys: List;

        pub fn new() -> Self {
            return Self { values: {}, defaults: {}, required_keys: [] };
        }

        pub fn set_default(self, key: String, value: Any) {
            self.defaults[key] = value;
        }

        pub fn set(self, key: String, value: Any) {
            self.values[key] = value;
        }

        pub fn require(self, key: String) {
            self.required_keys.push(key);
        }

        pub fn get(self, key: String) -> Any? {
            if self.values[key] != null { return self.values[key]; }
            return self.defaults[key];
        }

        pub fn get_int(self, key: String) -> Int {
            let v = self.get(key);
            if v == null { return 0; }
            return v.to_int();
        }

        pub fn get_bool(self, key: String) -> Bool {
            let v = self.get(key);
            if v == null { return false; }
            return v == true or v == "true" or v == "1";
        }

        pub fn validate(self) -> List {
            let missing = [];
            for key in self.required_keys {
                if self.get(key) == null { missing.push(key); }
            }
            return missing;
        }

        pub fn from_map(self, map: Map) {
            for key in map.keys() { self.values[key] = map[key]; }
        }
    }

    pub class FeatureFlag {
        pub let name: String;
        pub let enabled: Bool;
        pub let rollout_pct: Float;
        pub let metadata: Map;

        pub fn new(name: String, enabled: Bool) -> Self {
            return Self { name: name, enabled: enabled, rollout_pct: 100.0, metadata: {} };
        }

        pub fn is_enabled(self) -> Bool {
            return self.enabled;
        }

        pub fn is_enabled_for(self, user_id: String) -> Bool {
            if !self.enabled { return false; }
            if self.rollout_pct >= 100.0 { return true; }
            let hash = user_id.len() % 100;
            return hash < self.rollout_pct.to_int();
        }
    }

    pub class FeatureFlagManager {
        pub let flags: Map;

        pub fn new() -> Self {
            return Self { flags: {} };
        }

        pub fn register(self, flag: FeatureFlag) {
            self.flags[flag.name] = flag;
        }

        pub fn is_enabled(self, name: String) -> Bool {
            if self.flags[name] == null { return false; }
            return self.flags[name].is_enabled();
        }

        pub fn is_enabled_for(self, name: String, user_id: String) -> Bool {
            if self.flags[name] == null { return false; }
            return self.flags[name].is_enabled_for(user_id);
        }
    }
}

pub mod lifecycle {

    pub class Phase {
        pub let name: String;
        pub let order: Int;
        pub let handler: Fn;
        pub let completed: Bool;

        pub fn new(name: String, order: Int, handler: Fn) -> Self {
            return Self { name: name, order: order, handler: handler, completed: false };
        }
    }

    pub class LifecycleManager {
        pub let phases: List;
        pub let current_phase: String;
        pub let state: String;
        pub let hooks: Map;

        pub fn new() -> Self {
            return Self {
                phases: [],
                current_phase: "init",
                state: "created",
                hooks: {}
            };
        }

        pub fn add_phase(self, phase: Phase) {
            self.phases.push(phase);
            self.phases.sort_by(fn(a, b) { a.order - b.order });
        }

        pub fn on(self, event: String, handler: Fn) {
            if self.hooks[event] == null { self.hooks[event] = []; }
            self.hooks[event].push(handler);
        }

        pub fn start(self) {
            self.state = "starting";
            self._emit("before_start");
            for phase in self.phases {
                self.current_phase = phase.name;
                phase.handler();
                phase.completed = true;
            }
            self.state = "running";
            self._emit("after_start");
        }

        pub fn stop(self) {
            self.state = "stopping";
            self._emit("before_stop");
            for phase in self.phases.reverse() {
                self.current_phase = "teardown_" + phase.name;
            }
            self.state = "stopped";
            self._emit("after_stop");
        }

        fn _emit(self, event: String) {
            if self.hooks[event] != null {
                for handler in self.hooks[event] { handler(); }
            }
        }

        pub fn is_running(self) -> Bool {
            return self.state == "running";
        }
    }

    pub class ResourcePool {
        pub let name: String;
        pub let resources: List;
        pub let max_size: Int;
        pub let in_use: Int;

        pub fn new(name: String, max_size: Int) -> Self {
            return Self { name: name, resources: [], max_size: max_size, in_use: 0 };
        }

        pub fn acquire(self) -> Any? {
            if self.resources.len() > 0 {
                self.in_use = self.in_use + 1;
                return self.resources.pop();
            }
            if self.in_use < self.max_size {
                self.in_use = self.in_use + 1;
                return {};
            }
            return null;
        }

        pub fn release(self, resource: Any) {
            self.in_use = self.in_use - 1;
            self.resources.push(resource);
        }

        pub fn available(self) -> Int {
            return self.max_size - self.in_use;
        }
    }
}
