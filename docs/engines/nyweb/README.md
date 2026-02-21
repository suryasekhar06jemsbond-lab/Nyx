# Nyx Web Guide: Build Full High-End Websites Easily

This is a complete practical guide for users who want to build modern websites in Nyx with simple syntax.

Main goals:
- Easy UI syntax (`ui.*`) with no `nyui.strict.*` typing
- Full website capability (pages, assets/images, APIs, interactivity)
- Nyx-native styling (no external style file dependency)
- Built-in local Nyx memory store (no external database dependency)
- Native runtime stack: SSR/CSR toggle, hydration, diff rendering, reactive state, middleware, security, WebSocket, plugins
- Clear run commands for Windows and Linux

---

## 1. New Easy UI Syntax (No `strict`)

Old style (still supported):

```ny
return nyui.strict.Container({"class": "page"}, [nyui.strict.Text("Hello")]);
```

New recommended style:

```ny
return ui.Container({"class": "page"}, [ui.Text("Hello")]);
```

You only need:

```ny
use nyui;
```

`ui` is available globally as the modern UI builder layer.

Ultra-short style is also available:

```ny
return Container({"class": "page"}, [Text("Hello")]);
```

---

## 2. What You Can Build

With Nyx web stack you can build:
- multi-page websites
- API backends
- image/media-rich pages
- interactive frontend behavior
- dashboard + form workflows
- data-driven apps with built-in local Nyx store

Core modules:
- `nyui` for UI + website orchestration
- `nyweb` for HTTP hosting/runtime
- `nyweb.LocalStore` for local data operations

---

## 3. Quick Start Commands

### Windows (PowerShell/CMD)

From repo root:

```bat
python nyx_runtime.py engines\nyui\test_web_host.ny
```

If `python` is not recognized:

```bat
py nyx_runtime.py engines\nyui\test_web_host.ny
```

Open:
- `http://127.0.0.1:8080`

Stop:
- `Ctrl + C`

### Linux/macOS

```bash
python3 nyx_runtime.py tests/nyui/test_web_host.ny
```

Open:
- `http://127.0.0.1:8080`

---

## 4. Full High-End Website Example (Modern Syntax)

> Working full example file is here:
> `tests/nyui/test_web_host.ny`

This example includes:
- routes: `/`, `/about`, `/dashboard`
- APIs: `/api/health`, `/api/leads`
- image assets from `/assets`
- styling from Nyx theme maps inside `.ny` (`site.withThemeMap(...)`)
- interactive counter + form submit
- local store persistence
- SSR/CSR/hybrid runtime controls with hydration + diff endpoint + security + websocket + plugin hooks

Minimal structure pattern:

```ny
use nyui;
use nyweb;

let store = nyweb.LocalStore.new();

fn initStore() {
    if store.tableExists("leads") {
        return;
    } else {
        store.createTable("leads", ["id", "name", "email", "message", "created_at"], "id", true);
    }
}

fn appThemeMap() {
    return {
        "Container": {"color": "#0f172a"},
        ".page": {"padding": "24px", "background": "#f8fafc", "minHeight": "100vh"},
        ".title": {"fontSize": "30px", "fontWeight": "800"},
        ".btn": {"padding": "10px 16px", "border": "none", "borderRadius": "10px", "background": "#2563eb", "color": "#fff"},
        "@media (max-width:900px)": {
            ".page": {"fontSize": "14px"}
        }
    };
}

fn homePage(params) {
    return ui.Container(
        {"class": "page"},
        [
            ui.Container({"class": "title"}, [ui.Text("Nyx Website")]),
            ui.Image({"src": "/assets/nyx-logo.svg", "alt": "logo"}),
            ui.Button({"id": "cta", "class": "btn"}, [ui.Text("Click")])
        ]
    );
}

fn apiHealth(request) {
    return {"ok": true, "service": "nyx-web"};
}

pub fn main() {
    initStore();

    let site = nyui.createWebsite("MySite");
    site = site.pageTitle("My High-End Nyx Site");
    site = site.public("assets", "/assets");
    site = site.withThemeMap(appThemeMap());

    site = site.get("/", homePage);
    site = site.getApi("/api/health", apiHealth);

    site.run("127.0.0.1", 8080);
}
```

---

## 5. Website Builder API Reference

### Core page routing
- `site.get(path, pageHandler)`
- `site.notFound(handler)`

### API routing
- `site.getApi(path, handler)`
- `site.postApi(path, handler)`
- `site.putApi(path, handler)`
- `site.deleteApi(path, handler)`

API handler receives `request` and can return:
- `Dict`/`List` -> auto JSON response
- `String` -> text response
- `nyweb.Response` -> full manual response control

### Head + SEO + assets
- `site.pageTitle(title)`
- `site.locale(lang)`
- `site.meta(name, content)`
- `site.favicon(href)`
- `site.withThemeMap(styleMap)` (recommended: NYX-native style map)
- `site.headLink(rel, href)`
- `site.headScript(src)`
- `site.inlineScript(js)`

### Runtime mode + hydration + state
- `site.renderMode("ssr" | "csr" | "hybrid")`
- `site.modeProvider(fn() -> String)` (dynamic mode resolution per render)
- `site.hydrate(stateMap, rootId)` (hydration payload + client bootstrap)
- `site.withState(stateStoreOrMap)` (state abstraction)
- `site.diffRendering(true)` (enables `/__nyx/diff`)
- `site.persistent(path)` (persists runtime state)

### Security + middleware
- `site.use(middleware)` / `site.useFn(handler)`
- `site.securityLayer(csrfEnabled, rateLimit, rateWindowSeconds)`
- `site.validate(ruleFn, message)` (request validation)
- CSRF token exposed in `X-NYX-CSRF` response header and `nyx_csrf` cookie

### WebSocket + plugins
- `site.ws(path, wsHandler)` / `site.websocket(path, wsHandler)`
- `site.plugin(pluginObj)` / `site.usePlugin(pluginObj)`
- Plugin hooks: `setup(site)`, `middleware()`, `apply(app, site)`, `on_start(app, site)`

### Static hosting
- `site.public(directory, urlPrefix)`
- `site.mountStatic(urlPrefix, directory)`
- `site.asset("img/logo.svg")` -> generates asset URL string

Nyx-native theme example (no external style file):

```ny
site = site.withThemeMap({
    "Container": {"color": "#0f172a"},
    ".page": {"display": "flex", "gap": "12px"},
    ".btn": {"padding": "10px 16px", "background": "#2563eb", "color": "#fff"},
    "@media (max-width:900px)": {
        ".page": {"flexDirection": "column"}
    }
});
```

### Run
- `site.run(host, port)`

Native runtime helper endpoints:
- `GET /__nyx/hydrate` (hydration payload)
- `GET /__nyx/diff?path=/target` (diff updates)

---

## 6. Local Nyx Store (No External Database Engine)

Nyx provides local memory storage through `nyweb.LocalStore`.

Create store:

```ny
let store = nyweb.LocalStore.new();
```

Define table:

```ny
store.createTable("users", ["id", "name", "email", "created_at"], "id", true);
```

Insert:

```ny
store.insert("users", {"name": "Ava", "email": "ava@example.com"});
```

Select:

```ny
let rows = store.select("users", {}, ["id", "name", "email"], 20, "id", true);
```

Update:

```ny
store.update("users", {"name": "Ava Prime"}, {"id": 1});
```

Delete:

```ny
store.delete("users", {"id": 1});
```

Count:

```ny
let total = store.count("users");
```

---

## 7. UI Components You Can Use with `ui.*`

Examples:
- `ui.Container`, `ui.Text`, `ui.Button`, `ui.Link`
- `ui.Form`, `ui.Input`, `ui.TextArea`, `ui.Select`, `ui.Option`
- `ui.Image`, `ui.Video`, `ui.Audio`, `ui.Canvas`
- `ui.Row`, `ui.Column`, `ui.Card`, `ui.Grid`, `ui.Stack`
- `ui.Table`, `ui.TableHead`, `ui.TableBody`, `ui.TableRow`, `ui.TableCell`
- `ui.Fragment`

Custom component-to-tag mapping:

```ny
nyui.registerComponent("HeroPanel", "section");
let hero = ui.node("HeroPanel", {"class": "hero"}, [ui.Text("Welcome")]);
```

---

## 8. Interactivity Model

Use browser-side logic with:
- `site.inlineScript("...")`
- external script via `site.headScript("/assets/app.js")`

Typical use:
- handle click events
- submit form data to Nyx API endpoints
- update DOM for instant UX

---

## 9. Recommended Project Structure

```text
assets/
  nyx-logo.svg
apps/
  mysite.ny
engines/
  nyui/
  nyweb/
.nyx/
  stability.json
docs/
  engines/
    nyweb/
      README.md
```

---

## 10. Stability Strategy (So You Don’t Keep Rewriting Core)

To reduce future changes in parser/runtime/compiler:
- keep app features in route handlers, APIs, and component functions
- use `site.*` extension points for head/scripts/static/API
- keep compatibility config in `.nyx/stability.json`
- avoid hard-coding new behavior in multiple engine files when a route/API/plugin-style extension can solve it

Design rule:
- add new product features in app layer first
- add runtime/core changes only when absolutely required

---

## 11. Troubleshooting

### `ui` not recognized
- Ensure `use nyui;` is present.
- Run using updated runtime: `python nyx_runtime.py <file>.ny`.

### Images not loading
- Check `site.public("assets", "/assets")`.
- Confirm file exists under `assets/`.

### API returns 404
- Check API route registration and path string.
- Confirm method type (`getApi` vs `postApi`).

### Port already in use
- Change port: `site.run("127.0.0.1", 8081)`.

---

## 12. Migration Tip (Old -> New Syntax)

You can migrate gradually.

Old:

```ny
return nyui.strict.Container(...)
```

New:

```ny
return ui.Container(...)
```

Both can coexist while migrating, but new projects should use `ui.*`.
