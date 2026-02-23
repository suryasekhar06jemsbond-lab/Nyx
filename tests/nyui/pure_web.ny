# ============================================================
# NYX Language Website (NYX Only)
# ============================================================
# Run:
#   python3 nyx_runtime.py tests/nyui/pure_web.ny
#
# Output behavior:
# - Community signups are generated as files under tests/nyui/NYX PORTAL/.

use nyui;
use nyweb;

let SITE_NAME = "Nyx Programming Language";
let SITE_TAGLINE = "Build fast systems with expressive syntax and production tooling.";
let PORTAL_DIR = "tests/nyui/NYX PORTAL";

let appStore = nyweb.LocalStore.new();
let counterStore = nyweb.persistent(PORTAL_DIR + "/_counter.json");
let metricsStore = nyweb.persistent(PORTAL_DIR + "/_metrics.json");

let appState = nyweb.state({
    "visits": metricsStore.get("visits", 0) or 0,
    "signups": metricsStore.get("signups", 0) or 0,
    "playground_runs": metricsStore.get("playground_runs", 0) or 0
});

fn initialize() {
    if not counterStore.has("value") {
        counterStore.set("value", 0);
    }

    if not appStore.tableExists("community") {
        appStore.createTable(
            "community",
            [
                "id",
                "signup_no",
                "name",
                "email",
                "role",
                "focus",
                "created_at",
                "file_path"
            ],
            "id",
            true
        );
    }

    let readyStore = nyweb.persistent(PORTAL_DIR + "/.ready.json");
    readyStore.set("ready", true);

    refreshStats();
}

fn zeroPad(n, width) {
    let s = str(n);
    while len(s) < width {
        s = "0" + s;
    }
    return s;
}

fn nextSignupNumber() {
    let current = int(counterStore.get("value", 0) or 0) + 1;
    counterStore.set("value", current);
    return "NYX-" + zeroPad(current, 6);
}

fn refreshStats() {
    let rows = appStore.select("community", {}, ["id"], 500000, "id", true);
    let total = len(rows);
    appState.set("signups", total);
    metricsStore.set("signups", total);
}

fn hitVisitCounter() {
    let current = int(appState.get("visits", 0) or 0) + 1;
    appState.set("visits", current);
    metricsStore.set("visits", current);
}

fn bumpPlaygroundRuns() {
    let current = int(appState.get("playground_runs", 0) or 0) + 1;
    appState.set("playground_runs", current);
    metricsStore.set("playground_runs", current);
}

fn siteThemeMap() {
    return {
        ".page": { "minHeight": "100vh", "background": "radial-gradient(1200px 720px at 8% -10%, #22d3ee 0%, #0b1220 46%, #030712 100%)", "color": "#dbeafe", "fontFamily": "Manrope, Segoe UI, Arial, sans-serif", "padding": "24px" },
        ".nav": { "display": "flex", "justifyContent": "space-between", "alignItems": "center", "gap": "16px", "padding": "14px 18px", "borderRadius": "16px", "background": "rgba(15,23,42,0.65)", "border": "1px solid rgba(148,163,184,0.24)", "backdropFilter": "blur(8px)", "position": "sticky", "top": "10px", "zIndex": "50" },
        ".brand": { "fontSize": "21px", "fontWeight": "900", "letterSpacing": "0.2px", "color": "#f8fafc" },
        ".navLinks": { "display": "flex", "gap": "12px", "flexWrap": "wrap" },
        ".navLink": { "color": "#bfdbfe", "textDecoration": "none", "fontWeight": "700", "padding": "8px 12px", "borderRadius": "10px", "background": "rgba(2,6,23,0.38)" },
        ".hero": { "marginTop": "22px", "padding": "28px", "borderRadius": "22px", "background": "linear-gradient(145deg, rgba(14,165,233,0.20), rgba(15,23,42,0.72))", "border": "1px solid rgba(56,189,248,0.35)", "boxShadow": "0 20px 52px rgba(0,0,0,0.36)" },
        ".heroTitle": { "fontSize": "44px", "lineHeight": "1.04", "fontWeight": "900", "color": "#f8fafc" },
        ".heroSubtitle": { "marginTop": "12px", "fontSize": "18px", "color": "#bfdbfe", "maxWidth": "860px" },
        ".heroMeta": { "marginTop": "16px", "display": "flex", "gap": "10px", "flexWrap": "wrap" },
        ".chip": { "padding": "8px 12px", "borderRadius": "999px", "fontSize": "13px", "fontWeight": "700", "background": "rgba(14,116,144,0.22)", "border": "1px solid rgba(56,189,248,0.45)", "color": "#e0f2fe" },
        ".statsGrid": { "marginTop": "20px", "display": "grid", "gridTemplateColumns": "repeat(3, minmax(0, 1fr))", "gap": "12px" },
        ".statCard": { "padding": "14px", "borderRadius": "16px", "background": "rgba(15,23,42,0.65)", "border": "1px solid rgba(148,163,184,0.2)" },
        ".statLabel": { "fontSize": "12px", "color": "#94a3b8", "fontWeight": "700", "letterSpacing": "0.4px", "textTransform": "uppercase" },
        ".statValue": { "marginTop": "6px", "fontSize": "28px", "fontWeight": "900", "color": "#f0f9ff" },
        ".section": { "marginTop": "22px", "padding": "20px", "borderRadius": "18px", "background": "rgba(15,23,42,0.56)", "border": "1px solid rgba(148,163,184,0.2)" },
        ".sectionTitle": { "fontSize": "30px", "fontWeight": "900", "color": "#f8fafc" },
        ".sectionIntro": { "marginTop": "8px", "color": "#cbd5e1" },
        ".featureGrid": { "marginTop": "16px", "display": "grid", "gridTemplateColumns": "repeat(3, minmax(0, 1fr))", "gap": "12px" },
        ".featureCard": { "padding": "14px", "borderRadius": "14px", "background": "rgba(2,6,23,0.56)", "border": "1px solid rgba(125,211,252,0.2)" },
        ".featureTitle": { "fontSize": "18px", "fontWeight": "800", "color": "#e0f2fe" },
        ".featureText": { "marginTop": "6px", "color": "#cbd5e1" },
        ".twoCol": { "display": "grid", "gridTemplateColumns": "1.05fr 1fr", "gap": "14px", "marginTop": "16px" },
        ".panelList": { "display": "flex", "flexDirection": "column", "gap": "10px", "marginTop": "12px" },
        ".panelItem": { "padding": "12px", "borderRadius": "12px", "background": "rgba(2,6,23,0.50)", "border": "1px solid rgba(148,163,184,0.18)" },
        ".codeCard": { "padding": "14px", "borderRadius": "14px", "background": "rgba(2,6,23,0.66)", "border": "1px solid rgba(56,189,248,0.3)", "fontFamily": "Consolas, Menlo, monospace", "whiteSpace": "pre-wrap" },
        ".formCard": { "padding": "16px", "borderRadius": "16px", "background": "linear-gradient(170deg, rgba(2,132,199,0.20), rgba(15,23,42,0.66))", "border": "1px solid rgba(56,189,248,0.45)" },
        ".formGrid": { "display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "10px", "marginTop": "12px" },
        ".field": { "padding": "11px", "borderRadius": "10px", "border": "1px solid rgba(148,163,184,0.35)", "background": "rgba(15,23,42,0.8)", "color": "#f8fafc" },
        ".wide": { "gridColumn": "span 2" },
        ".btn": { "marginTop": "12px", "padding": "12px 16px", "border": "none", "borderRadius": "12px", "fontWeight": "900", "cursor": "pointer", "background": "linear-gradient(90deg, #06b6d4, #3b82f6)", "color": "#f8fafc" },
        ".resultBox": { "marginTop": "12px", "padding": "12px", "borderRadius": "12px", "background": "rgba(15,23,42,0.78)", "border": "1px dashed rgba(125,211,252,0.55)", "color": "#e2e8f0", "fontWeight": "700", "minHeight": "20px" },
        ".foot": { "marginTop": "24px", "padding": "16px", "textAlign": "center", "color": "#94a3b8" },
        "@media (max-width:1100px)": {
            ".featureGrid": { "gridTemplateColumns": "1fr 1fr" },
            ".twoCol": { "gridTemplateColumns": "1fr" }
        },
        "@media (max-width:780px)": {
            ".heroTitle": { "fontSize": "32px" },
            ".featureGrid": { "gridTemplateColumns": "1fr" },
            ".formGrid": { "gridTemplateColumns": "1fr" },
            ".wide": { "gridColumn": "span 1" },
            ".statsGrid": { "gridTemplateColumns": "1fr" },
            ".page": { "padding": "14px" }
        }
    };
}

fn navBar() {
    return ui.Container(
        { "class": "nav" },
        [
            ui.Container({ "class": "brand" }, [ui.Text(SITE_NAME)]),
            ui.Container(
                { "class": "navLinks" },
                [
                    ui.Link({ "href": "/", "class": "navLink" }, [ui.Text("Home")]),
                    ui.Link({ "href": "/docs", "class": "navLink" }, [ui.Text("Docs")]),
                    ui.Link({ "href": "/ecosystem", "class": "navLink" }, [ui.Text("Ecosystem")]),
                    ui.Link({ "href": "/playground", "class": "navLink" }, [ui.Text("Playground")]),
                    ui.Link({ "href": "/api/overview", "class": "navLink" }, [ui.Text("API")])
                ]
            )
        ]
    );
}

fn chip(text) {
    return ui.Container({ "class": "chip" }, [ui.Text(text)]);
}

fn statCard(label, value) {
    return ui.Card(
        { "class": "statCard" },
        [
            ui.Container({ "class": "statLabel" }, [ui.Text(label)]),
            ui.Container({ "class": "statValue" }, [ui.Text(value)])
        ]
    );
}

fn featureCard(title, body) {
    return ui.Card(
        { "class": "featureCard" },
        [
            ui.Container({ "class": "featureTitle" }, [ui.Text(title)]),
            ui.Container({ "class": "featureText" }, [ui.Text(body)])
        ]
    );
}

fn panelItem(title, detail) {
    return ui.Container(
        { "class": "panelItem" },
        [
            ui.Container({ "class": "featureTitle" }, [ui.Text(title)]),
            ui.Container({ "class": "featureText" }, [ui.Text(detail)])
        ]
    );
}

fn codeCard(codeText) {
    return ui.Container({ "class": "codeCard" }, [ui.Text(codeText)]);
}

fn communityCard() {
    return ui.Card(
        { "class": "formCard" },
        [
            ui.Container({ "class": "sectionTitle" }, [ui.Text("Join The Nyx Community")]),
            ui.Container({ "class": "sectionIntro" }, [ui.Text("Submit your profile. A NYX-only signup file is generated in tests/nyui/NYX PORTAL/.")]),
            ui.Form(
                { "id": "communityForm", "class": "formGrid" },
                [
                    ui.Input({ "id": "name", "class": "field", "placeholder": "Your name", "type": "text" }),
                    ui.Input({ "id": "email", "class": "field", "placeholder": "Your email", "type": "email" }),
                    ui.Input({ "id": "role", "class": "field", "placeholder": "Role (Student / Engineer / Researcher)", "type": "text" }),
                    ui.Input({ "id": "focus", "class": "field", "placeholder": "Focus area (Compiler / Runtime / AI / Web)", "type": "text" }),
                    ui.Button({ "type": "submit", "class": "btn wide" }, [ui.Text("Join Community")])
                ]
            ),
            ui.Container({ "id": "communityResult", "class": "resultBox" }, [ui.Text("No signup submitted yet.")])
        ]
    );
}

fn homePage(params) {
    let signups = str(int(appState.get("signups", 0) or 0));
    let visits = str(int(appState.get("visits", 0) or 0));
    let runs = str(int(appState.get("playground_runs", 0) or 0));

    return ui.Container(
        { "class": "page" },
        [
            navBar(),
            ui.Container(
                { "class": "hero" },
                [
                    ui.Container({ "class": "heroTitle" }, [ui.Text("Welcome To " + SITE_NAME)]),
                    ui.Container({ "class": "heroSubtitle" }, [ui.Text(SITE_TAGLINE)]),
                    ui.Container(
                        { "class": "heroMeta" },
                        [
                            chip("Native Runtime + VM"),
                            chip("Compiler + Tooling"),
                            chip("Engine Ecosystem"),
                            chip("Nyx-only Developer Flow")
                        ]
                    ),
                    ui.Container(
                        { "class": "statsGrid" },
                        [
                            statCard("Portal Visits", visits),
                            statCard("Community Signups", signups),
                            statCard("Playground Runs", runs)
                        ]
                    )
                ]
            ),
            ui.Container(
                { "class": "section" },
                [
                    ui.Container({ "class": "sectionTitle" }, [ui.Text("What Makes Nyx Different")]),
                    ui.Container({ "class": "sectionIntro" }, [ui.Text("Nyx combines systems-level control with high-level ergonomics and integrated engine modules.")]),
                    ui.Container(
                        { "class": "featureGrid" },
                        [
                            featureCard("Unified Toolchain", "Build, lint, debug, package, and release from a single language environment."),
                            featureCard("Production Runtime", "Native execution path with strict limits, observability hooks, and VM consistency gates."),
                            featureCard("Engine Modules", "nyweb, nyrender, nyanim, nyai, nynet, and more for full-stack product development."),
                            featureCard("Progressive Syntax", "Readable syntax for newcomers and precise constructs for advanced system work."),
                            featureCard("Deployment Ready", "Release scripts, platform packaging, and compatibility workflows included."),
                            featureCard("Extensible Core", "Parser, lexer, interpreter, ownership, and diagnostics modules are structured for growth.")
                        ]
                    )
                ]
            ),
            ui.Container(
                { "class": "section twoCol" },
                [
                    ui.Container(
                        {},
                        [
                            ui.Container({ "class": "sectionTitle" }, [ui.Text("Quick Start")]),
                            codeCard("make\n./build/nyx examples/fibonacci.ny"),
                            ui.Container({ "class": "panelList" }, [
                                panelItem("Language CLI", "Run parse-only, VM mode, strict mode, max-step limits, and version checks."),
                                panelItem("Docs", "Navigate to /docs for language principles, modules, and implementation guidance."),
                                panelItem("Ecosystem", "Navigate to /ecosystem for engines, workflows, and compatibility surfaces.")
                            ])
                        ]
                    ),
                    communityCard()
                ]
            ),
            ui.Container(
                { "class": "foot" },
                [ui.Text("© 2026 Nyx Language Portal | Built with NYX only")]
            )
        ]
    );
}

fn docsPage(params) {
    return ui.Container(
        { "class": "page" },
        [
            navBar(),
            ui.Container(
                { "class": "section" },
                [
                    ui.Container({ "class": "sectionTitle" }, [ui.Text("Nyx Docs Snapshot")]),
                    ui.Container({ "class": "sectionIntro" }, [ui.Text("Core concepts and developer-facing reference areas.")]),
                    ui.Container(
                        { "class": "panelList" },
                        [
                            panelItem("Language Core", "Expressions, modules, functions, classes, safety checks, and runtime behavior."),
                            panelItem("Runtime Flags", "--vm, --vm-strict, --parse-only, --max-steps, and --max-call-depth."),
                            panelItem("Build + Release", "Cross-platform scripts for testing, packaging, and CI hardening gates."),
                            panelItem("API Stability", "Core Python-side modules structured with explicit versioning and contract tests."),
                            panelItem("Security Posture", "Input checks, execution bounds, and deployment-oriented validation surfaces."),
                            panelItem("Native Hooks", "Engine gates mapped to native hook inventory for capability verification.")
                        ]
                    )
                ]
            )
        ]
    );
}

fn ecosystemPage(params) {
    return ui.Container(
        { "class": "page" },
        [
            navBar(),
            ui.Container(
                { "class": "section" },
                [
                    ui.Container({ "class": "sectionTitle" }, [ui.Text("Nyx Ecosystem")]),
                    ui.Container({ "class": "sectionIntro" }, [ui.Text("Engine-first modules for application, simulation, and production tooling.")]),
                    ui.Container(
                        { "class": "featureGrid" },
                        [
                            featureCard("nyweb", "Web routes, API surfaces, state handling, and server capabilities."),
                            featureCard("nyrender", "Rendering pipeline controls, asset graph workflows, and tiered output paths."),
                            featureCard("nyanim", "Animation systems, motion logic, and presentation timing control."),
                            featureCard("nyai", "AI workflow orchestration and hybrid execution sandboxes."),
                            featureCard("nynet", "Network integrity checks, sync validation, and transport-oriented utilities."),
                            featureCard("nycore", "Shared core systems, orchestration, and runtime policy foundations.")
                        ]
                    )
                ]
            )
        ]
    );
}

fn playgroundPage(params) {
    return ui.Container(
        { "class": "page" },
        [
            navBar(),
            ui.Container(
                { "class": "section" },
                [
                    ui.Container({ "class": "sectionTitle" }, [ui.Text("Nyx Playground")]),
                    ui.Container({ "class": "sectionIntro" }, [ui.Text("Run a lightweight snippet simulation and inspect response metadata.")]),
                    codeCard("fn hello(name) {\n    return \"Hello, \" + name + \" from Nyx\";\n}\n\nprint(hello(\"World\"));"),
                    ui.Button({ "id": "runPlayground", "class": "btn" }, [ui.Text("Run Playground Example")]),
                    ui.Container({ "id": "playgroundResult", "class": "resultBox" }, [ui.Text("No playground run yet.")])
                ]
            )
        ]
    );
}

fn validatePayload(request) {
    if request.path != "/api/community/subscribe" {
        return true;
    }

    let payload = request.json();
    if str(payload.get("email") or "") == "" {
        return "email is required";
    }
    if str(payload.get("name") or "") == "" {
        return "name is required";
    }
    return true;
}

fn requestTelemetry(request, next) {
    if request.method == "GET" {
        if request.path == "/" or request.path == "/docs" or request.path == "/ecosystem" or request.path == "/playground" {
            hitVisitCounter();
        }
    }

    let response = next(request);
    if response != null and response.headers != null {
        response.headers["X-NYX-SITE"] = "language-portal";
        response.headers["X-NYX-STACK"] = "nyx-only";
    }
    return response;
}

fn apiHealth(request) {
    return {
        "ok": true,
        "service": "nyx-language-portal",
        "visits": int(appState.get("visits", 0) or 0),
        "signups": int(appState.get("signups", 0) or 0),
        "playground_runs": int(appState.get("playground_runs", 0) or 0),
        "storage_dir": PORTAL_DIR
    };
}

fn apiOverview(request) {
    return {
        "ok": true,
        "name": SITE_NAME,
        "tagline": SITE_TAGLINE,
        "language_version": "v3.3.3",
        "engines": ["nyweb", "nyrender", "nyanim", "nyai", "nynet", "nycore"],
        "tooling": ["nypm", "nyfmt", "nylint", "nydbg"]
    };
}

fn apiMetrics(request) {
    return {
        "ok": true,
        "visits": int(appState.get("visits", 0) or 0),
        "signups": int(appState.get("signups", 0) or 0),
        "playground_runs": int(appState.get("playground_runs", 0) or 0)
    };
}

fn apiSubscribe(request) {
    let payload = request.json();

    let signupNo = nextSignupNumber();
    let createdAt = str(payload.get("submitted_at") or "");
    if createdAt == "" {
        createdAt = "client-generated";
    }

    let record = {
        "signup_no": signupNo,
        "name": str(payload.get("name") or ""),
        "email": str(payload.get("email") or ""),
        "role": str(payload.get("role") or ""),
        "focus": str(payload.get("focus") or ""),
        "created_at": createdAt
    };

    let filePath = PORTAL_DIR + "/" + signupNo + ".json";
    let fileStore = nyweb.persistent(filePath);
    fileStore.set("signup", record);

    appStore.insert("community", {
        "signup_no": signupNo,
        "name": record.get("name") or "",
        "email": record.get("email") or "",
        "role": record.get("role") or "",
        "focus": record.get("focus") or "",
        "created_at": createdAt,
        "file_path": filePath
    });

    refreshStats();

    return {
        "ok": true,
        "saved": true,
        "signup_no": signupNo,
        "file_path": filePath,
        "message": "Community profile saved in NYX PORTAL folder."
    };
}

fn apiPlaygroundRun(request) {
    bumpPlaygroundRuns();
    return {
        "ok": true,
        "status": "simulated-success",
        "output": "Hello, World from Nyx",
        "runs": int(appState.get("playground_runs", 0) or 0)
    };
}

fn appClientScript() {
    return (
        "var rid=function(){return 'nyx-'+Date.now()+'-'+Math.floor(Math.random()*1000000);};" +
        "var q=function(id){return document.getElementById(id);};" +
        "var refreshMetrics=function(){fetch('/api/metrics').then(function(r){return r.json();}).then(function(data){if(!data||!data.ok){return;} var v=q('liveVisits'); if(v){v.textContent=String(data.visits||0);} var s=q('liveSignups'); if(s){s.textContent=String(data.signups||0);} var p=q('liveRuns'); if(p){p.textContent=String(data.playground_runs||0);} }).catch(function(){});};" +
        "document.addEventListener('DOMContentLoaded',function(){refreshMetrics(); var f=q('communityForm'); if(f){f.addEventListener('submit',function(ev){ev.preventDefault(); var body={name:(q('name')&&q('name').value)||'',email:(q('email')&&q('email').value)||'',role:(q('role')&&q('role').value)||'',focus:(q('focus')&&q('focus').value)||'',submitted_at:new Date().toISOString()}; fetch('/api/community/subscribe',{method:'POST',headers:{'Content-Type':'application/json','X-NYX-Request-ID':rid()},body:JSON.stringify(body)}).then(function(r){return r.json();}).then(function(data){var out=q('communityResult'); if(!out){return;} if(data&&data.ok){out.textContent='Joined as '+data.signup_no+' | file: '+data.file_path; f.reset(); refreshMetrics();} else {out.textContent='Signup failed: '+((data&&data.error)||'unknown');}}).catch(function(){var out=q('communityResult'); if(out){out.textContent='Signup failed: network/runtime error';}});});}" +
        "var b=q('runPlayground'); if(b){b.addEventListener('click',function(){fetch('/api/playground/run',{method:'POST',headers:{'Content-Type':'application/json','X-NYX-Request-ID':rid()},body:'{}'}).then(function(r){return r.json();}).then(function(data){var out=q('playgroundResult'); if(!out){return;} if(data&&data.ok){out.textContent='Run #'+String(data.runs||0)+': '+String(data.output||''); refreshMetrics();} else {out.textContent='Playground run failed.';}}).catch(function(){var out=q('playgroundResult'); if(out){out.textContent='Playground run failed: network/runtime error';}});});}" +
        "});"
    );
}

pub fn main() {
    initialize();

    let site = nyui.createWebsite("NyxLanguageWebsite");
    site = site.pageTitle("Nyx Programming Language");
    site = site.locale("en");
    site = site.meta("description", "Nyx programming language portal built using NYX only.");
    site = site.public("assets", "/assets");
    site = site.favicon("/assets/nyx-logo.png");
    site = site.withThemeMap(siteThemeMap());
    site = site.withState(appState);
    site = site.renderMode("hybrid");
    site = site.hydrate(appState.snapshot(), "nyx-root");
    site = site.diffRendering(true);
    site = site.diffPolicy(2000);
    site = site.workerModel(256);
    site = site.observability(true, false, "/__nyx/metrics", "/__nyx/errors", "/__nyx/plugins", 200);
    site = site.securityLayer(false, 300, 60, null, 7200, "X-NYX-Request-ID", 120, true);
    site = site.validate(validatePayload, "Invalid payload");
    site = site.use(requestTelemetry);
    site = site.inlineScript(appClientScript());

    site = site.get("/", homePage);
    site = site.get("/docs", docsPage);
    site = site.get("/ecosystem", ecosystemPage);
    site = site.get("/playground", playgroundPage);

    site = site.getApi("/api/health", apiHealth);
    site = site.getApi("/api/overview", apiOverview);
    site = site.getApi("/api/metrics", apiMetrics);
    site = site.postApi("/api/community/subscribe", apiSubscribe);
    site = site.postApi("/api/playground/run", apiPlaygroundRun);

    print("Open: http://127.0.0.1:8080");
    print("Community files will be generated in: tests/nyui/NYX PORTAL/");

    site.run("127.0.0.1", 8080);
}
