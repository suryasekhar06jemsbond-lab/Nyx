# ============================================================
# Ultra Modern School Website (NYX Only)
# ============================================================
# Run:
#   python3 nyx_runtime.py examples/student/ultra_modern_school_website.ny
#
# Output requirement handled:
# - On every admission application, a dedicated admission file is generated.
# - Files are stored under: examples/STUDENT DETAILS/

use nyui;
use nyweb;

let SCHOOL_NAME = "Aurora International School";
let SCHOOL_TAGLINE = "Future-Ready Learning, Global Values, Creative Minds";
let ADMISSION_DIR = "examples/STUDENT DETAILS";

let appStore = nyweb.LocalStore.new();
let counterStore = nyweb.persistent("examples/STUDENT DETAILS/_counter.json");
let indexStore = nyweb.persistent("examples/STUDENT DETAILS/_index.json");

let appState = nyweb.state({
    "applications": indexStore.get("count", 0) or 0,
    "visits": indexStore.get("visits", 0) or 0
});

fn initialize() {
    if not counterStore.has("value") {
        counterStore.set("value", 0);
    }

    if not appStore.tableExists("admissions") {
        appStore.createTable(
            "admissions",
            [
                "id",
                "application_no",
                "student_name",
                "dob",
                "grade",
                "program",
                "email",
                "phone",
                "parent_name",
                "parent_phone",
                "address",
                "career_goal",
                "status",
                "file_path",
                "created_at"
            ],
            "id",
            true
        );
    }

    # This guarantees folder bootstrapping for STUDENT DETAILS.
    let readyStore = nyweb.persistent(ADMISSION_DIR + "/.ready.json");
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

fn nextAdmissionNumber() {
    let current = int(counterStore.get("value", 0) or 0) + 1;
    counterStore.set("value", current);
    return "ADMN-" + zeroPad(current, 6);
}

fn refreshStats() {
    let rows = appStore.select("admissions", {}, ["id"], 500000, "id", true);
    let total = len(rows);
    appState.set("applications", total);
    indexStore.set("count", total);
}

fn hitVisitCounter() {
    let current = int(appState.get("visits", 0) or 0) + 1;
    appState.set("visits", current);
    indexStore.set("visits", current);
}

fn appThemeMap() {
    return {
        ".page": { "minHeight": "100vh", "background": "radial-gradient(1200px 700px at 8% -10%, #2dd4bf 0%, #0f172a 45%, #020617 100%)", "color": "#e2e8f0", "fontFamily": "Manrope, Segoe UI, Arial, sans-serif", "padding": "26px" },
        ".nav": { "display": "flex", "justifyContent": "space-between", "alignItems": "center", "gap": "16px", "padding": "14px 18px", "borderRadius": "16px", "background": "rgba(15,23,42,0.62)", "border": "1px solid rgba(148,163,184,0.24)", "backdropFilter": "blur(8px)", "position": "sticky", "top": "10px", "zIndex": "50" },
        ".brand": { "fontSize": "20px", "fontWeight": "800", "letterSpacing": "0.2px", "color": "#f8fafc" },
        ".navLinks": { "display": "flex", "gap": "14px", "flexWrap": "wrap" },
        ".navLink": { "color": "#cbd5e1", "textDecoration": "none", "fontWeight": "700", "padding": "8px 12px", "borderRadius": "10px", "background": "rgba(15,23,42,0.25)" },
        ".hero": { "marginTop": "24px", "padding": "28px", "borderRadius": "22px", "background": "linear-gradient(145deg, rgba(14,116,144,0.24), rgba(30,41,59,0.72))", "border": "1px solid rgba(45,212,191,0.35)", "boxShadow": "0 20px 50px rgba(0,0,0,0.35)" },
        ".heroTitle": { "fontSize": "44px", "lineHeight": "1.04", "fontWeight": "900", "color": "#f8fafc" },
        ".heroSubtitle": { "marginTop": "12px", "fontSize": "18px", "color": "#bfdbfe", "maxWidth": "860px" },
        ".heroMeta": { "marginTop": "18px", "display": "flex", "gap": "12px", "flexWrap": "wrap" },
        ".chip": { "padding": "8px 12px", "borderRadius": "999px", "fontSize": "13px", "fontWeight": "700", "background": "rgba(2,132,199,0.22)", "border": "1px solid rgba(56,189,248,0.45)", "color": "#e0f2fe" },
        ".statsGrid": { "marginTop": "22px", "display": "grid", "gridTemplateColumns": "repeat(3, minmax(0, 1fr))", "gap": "14px" },
        ".statCard": { "padding": "16px", "borderRadius": "16px", "background": "rgba(15,23,42,0.65)", "border": "1px solid rgba(148,163,184,0.2)" },
        ".statLabel": { "fontSize": "12px", "color": "#94a3b8", "fontWeight": "700", "letterSpacing": "0.4px", "textTransform": "uppercase" },
        ".statValue": { "marginTop": "6px", "fontSize": "28px", "fontWeight": "900", "color": "#f0f9ff" },
        ".section": { "marginTop": "24px", "padding": "20px", "borderRadius": "18px", "background": "rgba(15,23,42,0.55)", "border": "1px solid rgba(148,163,184,0.2)" },
        ".sectionTitle": { "fontSize": "28px", "fontWeight": "900", "color": "#f8fafc" },
        ".sectionIntro": { "marginTop": "8px", "color": "#cbd5e1" },
        ".featureGrid": { "marginTop": "16px", "display": "grid", "gridTemplateColumns": "repeat(3, minmax(0, 1fr))", "gap": "12px" },
        ".featureCard": { "padding": "14px", "borderRadius": "14px", "background": "rgba(2,6,23,0.55)", "border": "1px solid rgba(125,211,252,0.2)" },
        ".featureTitle": { "fontSize": "18px", "fontWeight": "800", "color": "#e0f2fe" },
        ".featureText": { "marginTop": "6px", "color": "#cbd5e1" },
        ".twoCol": { "display": "grid", "gridTemplateColumns": "1.1fr 1fr", "gap": "14px", "marginTop": "16px" },
        ".prospectusList": { "display": "flex", "flexDirection": "column", "gap": "10px", "marginTop": "12px" },
        ".prospectusItem": { "padding": "12px", "borderRadius": "12px", "background": "rgba(2,6,23,0.5)", "border": "1px solid rgba(148,163,184,0.18)" },
        ".applyCard": { "padding": "16px", "borderRadius": "16px", "background": "linear-gradient(170deg, rgba(2,132,199,0.20), rgba(15,23,42,0.65))", "border": "1px solid rgba(56,189,248,0.45)" },
        ".formGrid": { "display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "10px", "marginTop": "12px" },
        ".field": { "padding": "11px", "borderRadius": "10px", "border": "1px solid rgba(148,163,184,0.35)", "background": "rgba(15,23,42,0.78)", "color": "#f8fafc" },
        ".wide": { "gridColumn": "span 2" },
        ".btn": { "marginTop": "12px", "padding": "12px 16px", "border": "none", "borderRadius": "12px", "fontWeight": "900", "cursor": "pointer", "background": "linear-gradient(90deg, #06b6d4, #3b82f6)", "color": "#f8fafc" },
        ".resultBox": { "marginTop": "12px", "padding": "12px", "borderRadius": "12px", "background": "rgba(15,23,42,0.78)", "border": "1px dashed rgba(125,211,252,0.55)", "color": "#e2e8f0", "fontWeight": "700", "minHeight": "20px" },
        ".foot": { "marginTop": "26px", "padding": "16px", "textAlign": "center", "color": "#94a3b8" },
        "@media (max-width:1100px)": {
            ".featureGrid": { "gridTemplateColumns": "1fr 1fr" },
            ".twoCol": { "gridTemplateColumns": "1fr" },
            ".statsGrid": { "gridTemplateColumns": "1fr 1fr 1fr" }
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
            ui.Container({ "class": "brand" }, [ui.Text(SCHOOL_NAME)]),
            ui.Container(
                { "class": "navLinks" },
                [
                    ui.Link({ "href": "/", "class": "navLink" }, [ui.Text("Home")]),
                    ui.Link({ "href": "/prospectus", "class": "navLink" }, [ui.Text("Prospectus")]),
                    ui.Link({ "href": "/admissions", "class": "navLink" }, [ui.Text("Admissions")]),
                    ui.Link({ "href": "/api/prospectus", "class": "navLink" }, [ui.Text("API")])
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

fn prospectusItem(title, detail) {
    return ui.Container(
        { "class": "prospectusItem" },
        [
            ui.Container({ "class": "featureTitle" }, [ui.Text(title)]),
            ui.Container({ "class": "featureText" }, [ui.Text(detail)])
        ]
    );
}

fn admissionFormCard() {
    return ui.Card(
        { "class": "applyCard" },
        [
            ui.Container({ "class": "sectionTitle" }, [ui.Text("Online Admission Application")]),
            ui.Container({ "class": "sectionIntro" }, [ui.Text("Submit your details. A dedicated admission file will be generated in examples/STUDENT DETAILS.")]),
            ui.Form(
                { "id": "admissionForm", "class": "formGrid" },
                [
                    ui.Input({ "id": "student_name", "class": "field", "placeholder": "Student full name", "type": "text" }),
                    ui.Input({ "id": "dob", "class": "field", "placeholder": "Date of birth (YYYY-MM-DD)", "type": "text" }),
                    ui.Input({ "id": "grade", "class": "field", "placeholder": "Grade applying for", "type": "text" }),
                    ui.Input({ "id": "program", "class": "field", "placeholder": "Program (STEM / Arts / Sports)", "type": "text" }),
                    ui.Input({ "id": "email", "class": "field", "placeholder": "Student email", "type": "email" }),
                    ui.Input({ "id": "phone", "class": "field", "placeholder": "Student phone", "type": "text" }),
                    ui.Input({ "id": "parent_name", "class": "field", "placeholder": "Parent / Guardian name", "type": "text" }),
                    ui.Input({ "id": "parent_phone", "class": "field", "placeholder": "Parent / Guardian phone", "type": "text" }),
                    ui.Input({ "id": "address", "class": "field wide", "placeholder": "Home address", "type": "text" }),
                    ui.TextArea({ "id": "career_goal", "class": "field wide", "rows": "4", "placeholder": "Career goal / interests" }, []),
                    ui.Button({ "type": "submit", "class": "btn wide" }, [ui.Text("Apply For Admission")])
                ]
            ),
            ui.Container({ "id": "admissionResult", "class": "resultBox" }, [ui.Text("No application submitted yet.")])
        ]
    );
}

fn homePage(params) {
    let totalApplications = str(int(appState.get("applications", 0) or 0));
    let visits = str(int(appState.get("visits", 0) or 0));

    return ui.Container(
        { "class": "page" },
        [
            navBar(),
            ui.Container(
                { "class": "hero" },
                [
                    ui.Container({ "class": "heroTitle" }, [ui.Text("Welcome To " + SCHOOL_NAME)]),
                    ui.Container({ "class": "heroSubtitle" }, [ui.Text(SCHOOL_TAGLINE)]),
                    ui.Container(
                        { "class": "heroMeta" },
                        [
                            chip("CBSE + International Curriculum"),
                            chip("STEM Labs + Robotics"),
                            chip("Sports Excellence Center"),
                            chip("Global Language Programs")
                        ]
                    ),
                    ui.Container(
                        { "class": "statsGrid" },
                        [
                            statCard("Applications", totalApplications),
                            statCard("Campus Visits", visits),
                            statCard("Admission Year", "2026-2027")
                        ]
                    )
                ]
            ),
            ui.Container(
                { "class": "section" },
                [
                    ui.Container({ "class": "sectionTitle" }, [ui.Text("Why Families Choose Aurora")]),
                    ui.Container({ "class": "sectionIntro" }, [ui.Text("A modern, holistic, and technology-enabled learning ecosystem for every learner.")]),
                    ui.Container(
                        { "class": "featureGrid" },
                        [
                            featureCard("Future Labs", "AI lab, robotics studio, maker spaces, and applied science workshops."),
                            featureCard("Personal Mentors", "Every child gets an academic mentor and a wellbeing advisor."),
                            featureCard("Global Competitions", "Olympiads, hackathons, debate leagues, and exchange programs."),
                            featureCard("Sports + Performance", "Olympic-size pool, multi-sport arena, music and theater academy."),
                            featureCard("Safe Smart Campus", "Biometric entry, GPS buses, health desk, and parent real-time alerts."),
                            featureCard("Career Readiness", "Portfolio, internships, entrepreneurship club, and college counseling.")
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
                            ui.Container({ "class": "sectionTitle" }, [ui.Text("Admission Prospectus Highlights")]),
                            ui.Container({ "class": "sectionIntro" }, [ui.Text("Transparent process, clear timelines, and supportive counseling.")]),
                            ui.Container(
                                { "class": "prospectusList" },
                                [
                                    prospectusItem("Eligibility", "Age-appropriate grade entry and previous academic records."),
                                    prospectusItem("Selection", "Aptitude interaction + parent counseling + document verification."),
                                    prospectusItem("Scholarships", "Merit, sports, arts, and need-based aid tracks available."),
                                    prospectusItem("Transport", "Smart routes with live tracking and staffed supervision."),
                                    prospectusItem("Programs", "STEM Scholar Track, Liberal Arts Track, and High Performance Sports Track."),
                                    prospectusItem("Support", "Inclusion unit, language bridge support, and counseling center.")
                                ]
                            )
                        ]
                    ),
                    admissionFormCard()
                ]
            ),
            ui.Container(
                { "class": "foot" },
                [ui.Text("© 2026 Aurora International School | Built with NYX only")]
            )
        ]
    );
}

fn prospectusPage(params) {
    let totalApplications = str(int(appState.get("applications", 0) or 0));

    return ui.Container(
        { "class": "page" },
        [
            navBar(),
            ui.Container(
                { "class": "section" },
                [
                    ui.Container({ "class": "sectionTitle" }, [ui.Text("Full Admission Prospectus")]),
                    ui.Container({ "class": "sectionIntro" }, [ui.Text("Everything students and parents need before applying.")]),
                    ui.Container(
                        { "class": "prospectusList" },
                        [
                            prospectusItem("Academic Calendar", "Session starts April 2026. Orientation week begins March 24, 2026."),
                            prospectusItem("Documents Required", "Birth certificate, last 2 report cards, ID proof, address proof, medical records."),
                            prospectusItem("Admission Steps", "Online application -> school interaction -> fee confirmation -> final enrollment."),
                            prospectusItem("Fee Guide", "Transparent annual fee slabs based on grade and selected program tracks."),
                            prospectusItem("Campus Facilities", "Digital classrooms, innovation labs, wellness center, and advanced sports complex."),
                            prospectusItem("Parent Partnership", "Dedicated parent portal, monthly progress reviews, and open teacher connect sessions.")
                        ]
                    ),
                    ui.Container({ "class": "resultBox" }, [ui.Text("Applications received so far: " + totalApplications)])
                ]
            )
        ]
    );
}

fn admissionsPage(params) {
    return ui.Container(
        { "class": "page" },
        [
            navBar(),
            ui.Container(
                { "class": "section" },
                [
                    ui.Container({ "class": "sectionTitle" }, [ui.Text("Apply For 2026-2027 Admissions")]),
                    ui.Container({ "class": "sectionIntro" }, [ui.Text("Complete the form below. Your dedicated admission file is auto-generated and stored in examples/STUDENT DETAILS.")]),
                    admissionFormCard(),
                    ui.Container({ "id": "admissionList", "class": "prospectusList" }, [
                        ui.Container({ "class": "prospectusItem" }, [ui.Text("Recent admissions will appear here after submissions.")])
                    ])
                ]
            )
        ]
    );
}

fn validateAdmissionPayload(request) {
    if request.path != "/api/admission/apply" {
        return true;
    }

    let payload = request.json();
    if str(payload.get("student_name") or "") == "" {
        return "student_name is required";
    }
    if str(payload.get("email") or "") == "" {
        return "email is required";
    }
    if str(payload.get("grade") or "") == "" {
        return "grade is required";
    }
    if str(payload.get("parent_name") or "") == "" {
        return "parent_name is required";
    }
    if str(payload.get("parent_phone") or "") == "" {
        return "parent_phone is required";
    }
    return true;
}

fn requestTelemetry(request, next) {
    if request.method == "GET" {
        if request.path == "/" or request.path == "/prospectus" or request.path == "/admissions" {
            hitVisitCounter();
        }
    }

    let response = next(request);
    if response != null and response.headers != null {
        response.headers["X-NYX-SCHOOL"] = "aurora";
        response.headers["X-NYX-STACK"] = "nyx-only";
    }
    return response;
}

fn apiHealth(request) {
    return {
        "ok": true,
        "service": "aurora-school-site",
        "applications": int(appState.get("applications", 0) or 0),
        "visits": int(appState.get("visits", 0) or 0),
        "storage_dir": ADMISSION_DIR
    };
}

fn apiProspectus(request) {
    return {
        "ok": true,
        "school": str(SCHOOL_NAME),
        "session": "2026-2027",
        "programs": [
            "STEM Scholar Track",
            "Liberal Arts Track",
            "Global Languages Track",
            "High Performance Sports Track"
        ],
        "admission_process": [
            "Apply online",
            "School interaction",
            "Document verification",
            "Fee confirmation",
            "Enrollment complete"
        ]
    };
}

fn apiAdmissionList(request) {
    let rows = appStore.select(
        "admissions",
        {},
        ["application_no", "student_name", "grade", "program", "status", "created_at", "file_path"],
        50,
        "id",
        false
    );

    return {
        "ok": true,
        "count": len(rows),
        "items": rows
    };
}

fn apiAdmissionApply(request) {
    let payload = request.json();

    let applicationNo = nextAdmissionNumber();
    let createdAt = str(payload.get("submitted_at") or "");
    if createdAt == "" {
        createdAt = "client-generated";
    }

    let record = {
        "application_no": applicationNo,
        "student_name": str(payload.get("student_name") or ""),
        "dob": str(payload.get("dob") or ""),
        "grade": str(payload.get("grade") or ""),
        "program": str(payload.get("program") or ""),
        "email": str(payload.get("email") or ""),
        "phone": str(payload.get("phone") or ""),
        "parent_name": str(payload.get("parent_name") or ""),
        "parent_phone": str(payload.get("parent_phone") or ""),
        "address": str(payload.get("address") or ""),
        "career_goal": str(payload.get("career_goal") or ""),
        "status": "submitted",
        "created_at": createdAt
    };

    let filePath = ADMISSION_DIR + "/" + applicationNo + ".json";
    let fileStore = nyweb.persistent(filePath);
    fileStore.set("admission", record);

    appStore.insert("admissions", {
        "application_no": applicationNo,
        "student_name": record.get("student_name") or "",
        "dob": record.get("dob") or "",
        "grade": record.get("grade") or "",
        "program": record.get("program") or "",
        "email": record.get("email") or "",
        "phone": record.get("phone") or "",
        "parent_name": record.get("parent_name") or "",
        "parent_phone": record.get("parent_phone") or "",
        "address": record.get("address") or "",
        "career_goal": record.get("career_goal") or "",
        "status": "submitted",
        "file_path": filePath,
        "created_at": createdAt
    });

    refreshStats();

    return {
        "ok": true,
        "saved": true,
        "application_no": applicationNo,
        "file_path": filePath,
        "message": "Admission submitted. File generated in STUDENT DETAILS folder."
    };
}

fn appClientScript() {
    return (
        "var rid=function(){return 'admn-'+Date.now()+'-'+Math.floor(Math.random()*1000000);};" +
        "var q=function(id){return document.getElementById(id);};" +
        "var pullList=function(){fetch('/api/admission/list').then(function(r){return r.json();}).then(function(data){var box=q('admissionList'); if(!box){return;} if(!data||!data.ok){box.innerHTML='<div class=\"prospectusItem\">Unable to load admission list.</div>'; return;} if(!data.items||data.items.length===0){box.innerHTML='<div class=\"prospectusItem\">No admissions yet.</div>'; return;} var html=''; for(var i=0;i<data.items.length;i++){var it=data.items[i]||{}; html += '<div class=\"prospectusItem\"><strong>'+ (it.application_no||'') +'</strong> | '+ (it.student_name||'') +' | Grade '+ (it.grade||'') +' | '+ (it.program||'') +'</div>'; } box.innerHTML=html; var c=q('admissionCountLive'); if(c){c.textContent=String(data.count||0);} }).catch(function(){var box=q('admissionList'); if(box){box.innerHTML='<div class=\"prospectusItem\">Admission list unavailable.</div>';}});};" +
        "document.addEventListener('DOMContentLoaded',function(){pullList(); var f=q('admissionForm'); if(!f){return;} f.addEventListener('submit',function(ev){ev.preventDefault(); var body={ student_name:(q('student_name')&&q('student_name').value)||'', dob:(q('dob')&&q('dob').value)||'', grade:(q('grade')&&q('grade').value)||'', program:(q('program')&&q('program').value)||'', email:(q('email')&&q('email').value)||'', phone:(q('phone')&&q('phone').value)||'', parent_name:(q('parent_name')&&q('parent_name').value)||'', parent_phone:(q('parent_phone')&&q('parent_phone').value)||'', address:(q('address')&&q('address').value)||'', career_goal:(q('career_goal')&&q('career_goal').value)||'', submitted_at:new Date().toISOString() }; fetch('/api/admission/apply',{ method:'POST', headers:{'Content-Type':'application/json','X-NYX-Request-ID':rid()}, body:JSON.stringify(body)}).then(function(r){return r.json();}).then(function(data){var out=q('admissionResult'); if(!out){return;} if(data&&data.ok){out.textContent='Application '+data.application_no+' submitted. File: '+data.file_path; f.reset(); pullList();} else {out.textContent='Submission failed: '+((data&&data.error)||'unknown error');}}).catch(function(){var out=q('admissionResult'); if(out){out.textContent='Submission failed: network/runtime error';}}); }); });"
    );
}

pub fn main() {
    initialize();

    let site = nyui.createWebsite("AuroraSchoolWebsite");
    site = site.pageTitle("Aurora International School - Admissions");
    site = site.locale("en");
    site = site.meta("description", "Ultra modern school website built using NYX only, with automated admission file generation.");
    site = site.public("assets", "/assets");
    site = site.favicon("/assets/nyx-logo.svg");
    site = site.withThemeMap(appThemeMap());
    site = site.withState(appState);
    site = site.renderMode("hybrid");
    site = site.hydrate(appState.snapshot(), "nyx-root");
    site = site.diffRendering(true);
    site = site.diffPolicy(2000);
    site = site.workerModel(256);
    site = site.observability(true, false, "/__nyx/metrics", "/__nyx/errors", "/__nyx/plugins", 200);
    site = site.securityLayer(false, 300, 60, null, 7200, "X-NYX-Request-ID", 120, true);
    site = site.validate(validateAdmissionPayload, "Invalid admission payload");
    site = site.use(requestTelemetry);
    site = site.inlineScript(appClientScript());

    site = site.get("/", homePage);
    site = site.get("/prospectus", prospectusPage);
    site = site.get("/admissions", admissionsPage);

    site = site.getApi("/api/health", apiHealth);
    site = site.getApi("/api/prospectus", apiProspectus);
    site = site.getApi("/api/admission/list", apiAdmissionList);
    site = site.postApi("/api/admission/apply", apiAdmissionApply);

    print("Open: http://127.0.0.1:8080");
    print("Admission files will be generated in: examples/STUDENT DETAILS/");

    site.run("127.0.0.1", 8080);
}
