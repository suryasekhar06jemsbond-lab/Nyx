# ============================================================
# Nyx World-Class Website Demo (Native NYX Runtime Stack)
# ============================================================
# Includes:
# - SSR / CSR / HYBRID render toggle
# - Hydration model
# - Component reactivity + state abstraction
# - Diff-based rendering endpoint
# - Middleware layer
# - Persistent storage engine
# - WebSocket route
# - Worker/concurrency model
# - Multi-instance state/security coordination
# - Observability (metrics/errors/traces)
# - Plugin architecture
# - Security layer (CSRF + validation + rate limiting)

use nyui;
use nyweb;

let store = nyweb.LocalStore.new();
let runtimeStore = nyweb.persistent(".nyx/web_state.json");

let appState = nyweb.state({
    "mode": runtimeStore.get("render_mode", "hybrid") or "hybrid",
    "hits": runtimeStore.get("hits", 0) or 0,
    "leadsSaved": runtimeStore.get("leadsSaved", 0) or 0,
    "counterSignal": runtimeStore.get("counterSignal", 0) or 0,
    "wsSeq": runtimeStore.get("wsSeq", 0) or 0
});

let counterSignal = Signal(int(appState.get("counterSignal", 0) or 0));

fn persistRuntimeState() {
    runtimeStore.set("render_mode", str(appState.get("mode", "hybrid") or "hybrid"));
    runtimeStore.set("hits", int(appState.get("hits", 0) or 0));
    runtimeStore.set("leadsSaved", int(appState.get("leadsSaved", 0) or 0));
    runtimeStore.set("counterSignal", int(appState.get("counterSignal", 0) or 0));
    runtimeStore.set("wsSeq", int(appState.get("wsSeq", 0) or 0));
}

fn onCounterChanged(value) {
    appState.set("counterSignal", int(value or 0));
    persistRuntimeState();
}

counterSignal.onChange(onCounterChanged);

fn initStore() {
    if store.tableExists("leads") {
        return;
    } else {
        store.createTable("leads", ["id", "name", "email", "message", "created_at"], "id", true);
    }
}

fn chooseMode() {
    let mode = str(appState.get("mode", "hybrid") or "hybrid");
    if mode == "ssr" {
        return "ssr";
    }
    if mode == "csr" {
        return "csr";
    }
    return "hybrid";
}

fn appThemeMap() {
    return {
        "Image": { "maxWidth": "100%", "display": "block" },
        "Input": { "font": "inherit" },
        "TextArea": { "font": "inherit" },
        "Button": { "font": "inherit" },
        "Select": { "font": "inherit" },
        ".pageRoot": { "padding": "24px", "background": "#f8fafc", "minHeight": "100vh", "fontFamily": "Manrope, Segoe UI, Arial, sans-serif", "color": "#0f172a" },
        ".navBar": { "display": "flex", "gap": "14px", "padding": "12px 16px", "background": "#0f172a", "borderRadius": "12px", "marginBottom": "18px", "flexWrap": "wrap" },
        ".navLink": { "color": "#e2e8f0", "textDecoration": "none", "fontWeight": "700" },
        ".heroPanel": { "padding": "20px", "borderRadius": "14px", "background": "#e2e8f0", "marginBottom": "16px" },
        ".heroTitle": { "fontSize": "34px", "fontWeight": "800", "lineHeight": "1.15" },
        ".heroLogo": { "marginTop": "14px", "width": "120px", "height": "120px", "borderRadius": "16px", "background": "#ffffff", "padding": "8px" },
        ".mutedLine": { "marginTop": "8px", "color": "#334155" },
        ".statusLine": { "marginTop": "10px", "color": "#0f172a", "fontWeight": "700" },
        ".twoCol": { "display": "flex", "gap": "12px", "alignItems": "stretch" },
        ".featureCard": { "flex": "1", "padding": "16px", "borderRadius": "12px", "background": "#ffffff", "boxShadow": "0 2px 10px rgba(2,6,23,0.08)" },
        ".sectionTitle": { "fontSize": "22px", "fontWeight": "700" },
        ".counterValue": { "marginTop": "10px", "fontSize": "28px", "fontWeight": "800" },
        ".formStack": { "display": "flex", "flexDirection": "column", "gap": "8px", "marginTop": "10px" },
        ".field": { "padding": "10px", "border": "1px solid #cbd5e1", "borderRadius": "8px" },
        ".btnBase": { "padding": "10px 16px", "border": "none", "borderRadius": "10px", "color": "#ffffff", "fontWeight": "700", "cursor": "pointer" },
        ".btnDark": { "marginTop": "12px", "background": "#111827" },
        ".btnBrand": { "marginTop": "4px", "background": "#2563eb" },
        ".jumpWrap": { "marginTop": "18px", "display": "flex", "gap": "12px", "flexWrap": "wrap" },
        ".jumpLink": { "color": "#1d4ed8", "fontWeight": "700", "textDecoration": "none" },
        ".infoCard": { "padding": "18px", "borderRadius": "12px", "background": "#ffffff", "boxShadow": "0 2px 10px rgba(2,6,23,0.08)" },
        ".pageTitleLarge": { "fontSize": "30px", "fontWeight": "800" },
        "@media (max-width:900px)": {
            ".pageRoot": { "fontSize": "14px" },
            ".counterValue": { "fontSize": "24px" },
            ".twoCol": { "flexDirection": "column" }
        }
    };
}

fn appClientScript() {
    return (
        "var nyxCookie=function(name){var m=document.cookie.match(new RegExp('(?:^|; )'+name+'=([^;]*)'));return m?decodeURIComponent(m[1]):'';};" +
        "var nyxToken=nyxCookie('nyx_csrf');" +
        "var nyxReqId=function(prefix){return prefix+'-'+Date.now()+'-'+Math.floor(Math.random()*1000000);};" +
        "var wsProto=(location.protocol==='https:'?'wss://':'ws://');" +
        "document.addEventListener('click',function(e){if(e.target&&e.target.dataset.counter==='1'){var el=document.getElementById('counterValue');if(el){var n=parseInt(el.textContent||'0',10);el.textContent=String(n+1);}}});" +
        "document.addEventListener('submit',function(e){if(e.target&&e.target.id==='leadForm'){e.preventDefault();var name=document.getElementById('leadName').value;var email=document.getElementById('leadEmail').value;var message=document.getElementById('leadMsg').value;fetch('/api/leads',{method:'POST',headers:{'Content-Type':'application/json','X-NYX-CSRF':nyxToken,'X-NYX-Request-ID':nyxReqId('lead')},body:JSON.stringify({name:name,email:email,message:message})}).then(function(){alert('Lead saved in local Nyx memory');});}});" +
        "var wsEl=document.getElementById('wsStatus');try{var ws=new WebSocket(wsProto+location.host+'/ws/live');ws.onopen=function(){if(wsEl){wsEl.textContent='Live socket: connected';}};ws.onmessage=function(ev){if(wsEl){wsEl.textContent='Live socket: '+ev.data;}};ws.onclose=function(){if(wsEl){wsEl.textContent='Live socket: closed';}};}catch(e){if(wsEl){wsEl.textContent='Live socket unavailable';}}"
    );
}

fn line(message) {
    return ui.Container({ "class": "mutedLine" }, [ui.Text(message)]);
}

fn statusLine(message) {
    return ui.Container({ "class": "statusLine" }, [ui.Text(message)]);
}

fn navBar() {
    return ui.Container(
        { "class": "navBar" },
        [
            ui.Link({ "href": "/", "class": "navLink" }, [ui.Text("Home")]),
            ui.Link({ "href": "/about", "class": "navLink" }, [ui.Text("About")]),
            ui.Link({ "href": "/dashboard", "class": "navLink" }, [ui.Text("Dashboard")])
        ]
    );
}

fn homePage(params) {
    let mode = str(appState.get("mode", "hybrid") or "hybrid");
    let hits = str(appState.get("hits", 0) or 0);
    let leadsSaved = str(appState.get("leadsSaved", 0) or 0);

    return ui.Container(
        { "class": "pageRoot" },
        [
            navBar(),
            ui.Container(
                { "class": "heroPanel" },
                [
                    ui.Container({ "class": "heroTitle" }, [ui.Text("Nyx Native Runtime Stack")]),
                    line("SSR/CSR mode toggle + hydration + reactivity + diff + middleware + security."),
                    statusLine("Active mode: " + mode),
                    statusLine("Page hits (state + persistent engine): " + hits),
                    statusLine("Leads saved (reactive signal): " + leadsSaved),
                    ui.Container({ "id": "wsStatus", "class": "statusLine" }, [ui.Text("Live socket: connecting...")]),
                    ui.Image({ "src": "/assets/nyx-logo.svg", "alt": "Nyx Logo", "class": "heroLogo" })
                ]
            ),
            ui.Container(
                { "class": "twoCol" },
                [
                    ui.Card(
                        { "class": "featureCard" },
                        [
                            ui.Container({ "class": "sectionTitle" }, [ui.Text("Interactive Counter")]),
                            line("Counter updates in browser immediately."),
                            ui.Container({ "id": "counterValue", "class": "counterValue" }, [ui.Text("0")]),
                            ui.Button({ "data-counter": "1", "class": "btnBase btnDark" }, [ui.Text("Increase")])
                        ]
                    ),
                    ui.Card(
                        { "class": "featureCard" },
                        [
                            ui.Container({ "class": "sectionTitle" }, [ui.Text("Lead Form -> Local Store")]),
                            line("POST /api/leads uses CSRF + validation + rate-limit + replay middleware."),
                            ui.Form(
                                { "id": "leadForm", "class": "formStack" },
                                [
                                    ui.Input({ "id": "leadName", "type": "text", "placeholder": "Name", "class": "field" }),
                                    ui.Input({ "id": "leadEmail", "type": "email", "placeholder": "Email", "class": "field" }),
                                    ui.TextArea({ "id": "leadMsg", "placeholder": "Message", "rows": "4", "class": "field" }, []),
                                    ui.Button({ "type": "submit", "class": "btnBase btnBrand" }, [ui.Text("Save Lead")])
                                ]
                            )
                        ]
                    )
                ]
            ),
            ui.Container(
                { "class": "jumpWrap" },
                [
                    ui.Link({ "href": "/dashboard", "class": "jumpLink" }, [ui.Text("Open Dashboard ->")]),
                    ui.Link({ "href": "/api/runtime", "class": "jumpLink" }, [ui.Text("Runtime API ->")]),
                    ui.Link({ "href": "/__nyx/diff?path=/", "class": "jumpLink" }, [ui.Text("Diff API ->")])
                ]
            )
        ]
    );
}

fn aboutPage(params) {
    return ui.Container(
        { "class": "pageRoot" },
        [
            navBar(),
            ui.Container(
                { "class": "infoCard" },
                [
                    ui.Container({ "class": "pageTitleLarge" }, [ui.Text("About This Runtime")]),
                    line("Render mode toggle: site.renderMode('ssr' | 'csr' | 'hybrid')."),
                    line("Hydration model: site.hydrate(state, rootId)."),
                    line("Reactivity: Signal + StateStore."),
                    line("Diff engine: site.diffRendering(true) + /__nyx/diff."),
                    line("Concurrency model: worker threads + guarded shared state."),
                    line("Multi-instance mode: site.multiInstance(path, namespace)."),
                    line("Observability: /__nyx/metrics + /__nyx/errors + /__nyx/plugins."),
                    line("Middleware + security: site.use(...) + site.securityLayer(...)."),
                    line("Replay safety: send X-NYX-Request-ID per mutating API request."),
                    line("Persistent storage: nyweb.persistent(...)."),
                    line("WebSocket route: site.ws('/ws/live', handler)."),
                    line("Plugin contract: priority + capabilities + fail_open + lifecycle order.")
                ]
            )
        ]
    );
}

fn dashboardPage(params) {
    let total = str(store.count("leads"));
    let hits = str(appState.get("hits", 0) or 0);
    let mode = str(appState.get("mode", "hybrid") or "hybrid");

    return ui.Container(
        { "class": "pageRoot" },
        [
            navBar(),
            ui.Container(
                { "class": "infoCard" },
                [
                    ui.Container({ "class": "pageTitleLarge" }, [ui.Text("Dashboard")]),
                    line("Render mode: " + mode),
                    line("Leads stored in local memory: " + total),
                    line("Tracked page hits: " + hits),
                    line("Hydration endpoint: /__nyx/hydrate"),
                    line("WebSocket route: /ws/live")
                ]
            )
        ]
    );
}

fn validateLeadPayload(request) {
    if request.path != "/api/leads" {
        return true;
    }
    let payload = request.json();
    let name = str(payload.get("name") or "");
    let email = str(payload.get("email") or "");
    if name == "" {
        return "name is required";
    }
    if email == "" {
        return "email is required";
    }
    return true;
}

fn requestTelemetry(request, next) {
    if request.method == "GET" and (request.path == "/" or request.path == "/about" or request.path == "/dashboard") {
        let hits = int(appState.get("hits", 0) or 0) + 1;
        appState.set("hits", hits);
        persistRuntimeState();
    }

    let response = next(request);
    if response != null and response.headers != null {
        response.headers["X-NYX-Middleware"] = "telemetry";
        response.headers["X-NYX-Render-Mode"] = str(appState.get("mode", "hybrid") or "hybrid");
    }
    return response;
}

class RuntimePlugin {
    fn setup(self, site) {
        print("RuntimePlugin setup");
        return site;
    }

    fn on_start(self, app, site) {
        print("RuntimePlugin on_start");
    }
}

fn liveSocket(ws, request) {
    ws.sendJson({
        "ok": true,
        "event": "connected",
        "mode": str(appState.get("mode", "hybrid") or "hybrid"),
        "hits": int(appState.get("hits", 0) or 0)
    });

    while true {
        let incoming = ws.receive();
        if incoming == null {
            break;
        }
        let seq = int(appState.get("wsSeq", 0) or 0) + 1;
        appState.set("wsSeq", seq);
        persistRuntimeState();
        ws.sendJson({ "ok": true, "seq": seq, "echo": str(incoming) });
    }
}

fn apiHealth(request) {
    return { "ok": true, "service": "nyx-web", "status": "ready" };
}

fn apiRuntime(request) {
    return {
        "ok": true,
        "render_mode": str(appState.get("mode", "hybrid") or "hybrid"),
        "features": {
            "hydration": true,
            "diff_rendering": true,
            "component_reactivity": true,
            "state_store": true,
            "middleware": true,
            "concurrency_guarantees": true,
            "multi_instance": true,
            "observability": true,
            "persistent_engine": true,
            "websocket": true,
            "plugin_architecture": true,
            "plugin_contract": true,
            "security": true,
            "replay_protection": true
        }
    };
}

fn apiModeGet(request) {
    return {
        "ok": true,
        "mode": str(appState.get("mode", "hybrid") or "hybrid"),
        "allowed": ["ssr", "csr", "hybrid"]
    };
}

fn apiModePost(request) {
    let payload = request.json();
    let mode = str(payload.get("mode") or "hybrid");
    if mode != "ssr" and mode != "csr" and mode != "hybrid" {
        return { "ok": false, "error": "mode must be one of ssr|csr|hybrid" };
    }
    appState.set("mode", mode);
    persistRuntimeState();
    return { "ok": true, "mode": mode };
}

fn apiLeadsGet(request) {
    let rows = store.select("leads", {}, ["id", "name", "email", "message", "created_at"], 20, "id", true);
    return { "ok": true, "count": rows.len(), "items": rows };
}

fn apiLeadsPost(request) {
    let payload = request.json();
    let name = payload.get("name") or "Guest";
    let email = payload.get("email") or "guest@example.com";
    let message = payload.get("message") or "";

    store.insert("leads", { "name": str(name), "email": str(email), "message": str(message) });

    let saved = int(appState.get("leadsSaved", 0) or 0) + 1;
    appState.set("leadsSaved", saved);
    counterSignal.set(int(counterSignal.get() or 0) + 1);
    persistRuntimeState();

    return { "ok": true, "saved": true, "leadsSaved": saved };
}

pub fn main() {
    initStore();

    let mode = chooseMode();
    let site = nyui.createWebsite("NyxWorldClass");
    site = site.pageTitle("Nyx World Class Website");
    site = site.locale("en");
    site = site.meta("description", "Nyx native stack with SSR/CSR, hydration, diff, state, middleware, persistence, websocket, plugin, security");
    site = site.public("assets", "/assets");
    site = site.favicon("/assets/nyx-logo.svg");
    site = site.withThemeMap(appThemeMap());
    site = site.withState(appState);
    site = site.renderMode(mode);
    site = site.modeProvider(chooseMode);
    site = site.hydrate(appState.snapshot(), "nyx-root");
    site = site.diffRendering(true);
    site = site.diffPolicy(2000);
    site = site.workerModel(256);
    site = site.multiInstance(".nyx/site_runtime_state.json", "nyxworld", true);
    site = site.observability(true, false, "/__nyx/metrics", "/__nyx/errors", "/__nyx/plugins", 200);
    site = site.pluginContract(false);
    site = site.securityLayer(true, 240, 60, null, 7200, "X-NYX-Request-ID", 120, false);
    site = site.validate(validateLeadPayload, "Invalid lead payload");
    site = site.wsPolicy(120, 262144, 2048, 262144);
    site = site.use(requestTelemetry);
    site = site.plugin(RuntimePlugin());
    site = site.ws("/ws/live", liveSocket);
    site = site.inlineScript(appClientScript());

    site = site.get("/", homePage);
    site = site.get("/about", aboutPage);
    site = site.get("/dashboard", dashboardPage);

    site = site.getApi("/api/health", apiHealth);
    site = site.getApi("/api/runtime", apiRuntime);
    site = site.getApi("/api/mode", apiModeGet);
    site = site.postApi("/api/mode", apiModePost);
    site = site.getApi("/api/leads", apiLeadsGet);
    site = site.postApi("/api/leads", apiLeadsPost);

    print("Open browser: http://127.0.0.1:8080");
    print("WebSocket: ws://127.0.0.1:8080/ws/live");
    print("Pages: /  /about  /dashboard");
    print("APIs: /api/health  /api/runtime  /api/mode  /api/leads  /__nyx/hydrate  /__nyx/diff  /__nyx/metrics  /__nyx/errors  /__nyx/plugins");

    site.run("127.0.0.1", 8080);
}
