module nyrender {
    fn base_styles() {
        let css = "";
        css = css + ":root {";
        css = css + "  --bg-0: #070a16;";
        css = css + "  --bg-1: #0e1d36;";
        css = css + "  --bg-2: #0c4b63;";
        css = css + "  --ink: #e6f3ff;";
        css = css + "  --ink-soft: #93b4cc;";
        css = css + "  --mint: #4ce6c5;";
        css = css + "  --sun: #f8cf61;";
        css = css + "  --rose: #ff6b7f;";
        css = css + "  --panel: rgba(8, 20, 42, 0.58);";
        css = css + "}";
        css = css + "* { box-sizing: border-box; }";
        css = css + "html, body { margin: 0; padding: 0; font-family: 'Segoe UI', 'Trebuchet MS', sans-serif; color: var(--ink); }";
        css = css + "body {";
        css = css + "  min-height: 100vh;";
        css = css + "  background: radial-gradient(1200px 900px at 10% -10%, #204780 0%, transparent 60%),";
        css = css + "              radial-gradient(900px 800px at 90% 10%, #123a57 0%, transparent 60%),";
        css = css + "              linear-gradient(155deg, var(--bg-0), var(--bg-1) 45%, var(--bg-2));";
        css = css + "}";
        css = css + ".wrap { width: min(1200px, 92vw); margin: 0 auto; }";
        css = css + ".topbar { position: sticky; top: 0; backdrop-filter: blur(12px); background: rgba(7, 10, 22, 0.62); border-bottom: 1px solid rgba(120,180,220,0.2); z-index: 20; }";
        css = css + ".topbar .wrap { display: flex; align-items: center; justify-content: space-between; padding: 14px 0; }";
        css = css + ".brand { font-weight: 800; letter-spacing: 0.04em; }";
        css = css + ".chip { border: 1px solid rgba(126, 220, 255, 0.36); color: var(--mint); border-radius: 999px; padding: 6px 10px; font-size: 12px; }";
        css = css + ".hero { padding: 82px 0 36px 0; }";
        css = css + ".hero-grid { display: grid; grid-template-columns: 1.2fr 0.8fr; gap: 18px; align-items: stretch; }";
        css = css + ".panel { background: var(--panel); border: 1px solid rgba(160, 220, 255, 0.23); border-radius: 20px; padding: 20px; box-shadow: 0 14px 60px rgba(0,0,0,0.28); }";
        css = css + "h1, h2, h3 { margin: 0 0 12px 0; line-height: 1.1; }";
        css = css + "h1 { font-size: clamp(30px, 6vw, 56px); }";
        css = css + ".sub { color: var(--ink-soft); font-size: clamp(14px, 2vw, 20px); max-width: 58ch; }";
        css = css + ".kpis { display: grid; gap: 12px; grid-template-columns: repeat(4, minmax(0, 1fr)); margin-top: 22px; }";
        css = css + ".kpi { padding: 14px; border-radius: 14px; border: 1px solid rgba(120,180,220,0.2); background: rgba(10,24,46,0.55); }";
        css = css + ".kpi .val { font-size: 28px; font-weight: 800; color: var(--sun); }";
        css = css + ".kpi .lbl { font-size: 12px; color: var(--ink-soft); letter-spacing: 0.05em; text-transform: uppercase; }";
        css = css + ".kpi .hint { font-size: 12px; color: #7fa2ba; margin-top: 6px; }";
        css = css + ".engines { padding: 18px 0 22px 0; }";
        css = css + ".engine-grid { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 12px; }";
        css = css + ".engine { padding: 14px; border-radius: 14px; border: 1px solid rgba(145, 215, 255, 0.2); background: rgba(8, 23, 44, 0.64); }";
        css = css + ".engine .name { font-size: 17px; font-weight: 700; }";
        css = css + ".engine .lane { font-size: 12px; color: var(--mint); text-transform: uppercase; letter-spacing: 0.06em; }";
        css = css + ".engine .state { margin-top: 10px; font-size: 12px; color: #d8fb9f; }";
        css = css + ".timeline { padding: 14px 0 40px 0; }";
        css = css + ".timeline-list { list-style: none; margin: 0; padding: 0; display: grid; gap: 10px; }";
        css = css + ".timeline-item { border-left: 2px solid rgba(76,230,197,0.7); padding: 10px 12px; background: rgba(8,19,35,0.56); border-radius: 0 12px 12px 0; }";
        css = css + ".timeline-score { font-weight: 700; color: var(--sun); }";
        css = css + ".footer { padding: 18px 0 40px 0; color: var(--ink-soft); font-size: 13px; }";
        css = css + "@media (max-width: 1020px) { .hero-grid { grid-template-columns: 1fr; } .kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); } .engine-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }";
        css = css + "@media (max-width: 620px) { .kpis { grid-template-columns: 1fr; } .engine-grid { grid-template-columns: 1fr; } }";
        return css;
    }

    fn hero(title, subtitle, banner) {
        let html = "";
        html = html + "<section class='hero'><div class='wrap hero-grid'>";
        html = html + "<article class='panel reveal'><h1>" + title + "</h1><p class='sub'>" + subtitle + "</p></article>";
        html = html + "<aside class='panel reveal'><h3>Runtime Signal</h3><p class='sub'>" + banner + "</p><div class='chip'>Nyx-only source pipeline</div></aside>";
        html = html + "</div></section>";
        return html;
    }

    fn kpi_grid(metrics) {
        let html = "";
        html = html + "<section class='wrap'><div class='kpis'>";
        for (m in metrics) {
            html = html + "<article class='kpi reveal'>";
            html = html + "<div class='val'>" + m.value + " " + m.unit + "</div>";
            html = html + "<div class='lbl'>" + m.label + "</div>";
            html = html + "<div class='hint'>" + m.hint + "</div>";
            html = html + "</article>";
        }
        html = html + "</div></section>";
        return html;
    }

    fn engine_grid(cards) {
        let html = "";
        html = html + "<section class='engines'><div class='wrap'><h2>Engine Fabric</h2><div class='engine-grid'>";
        for (c in cards) {
            html = html + "<article class='engine reveal'>";
            html = html + "<div class='name'>" + c.name + "</div>";
            html = html + "<div class='lane'>" + c.lane + "</div>";
            html = html + "<p>" + c.detail + "</p>";
            html = html + "<div class='state'>state: " + c.state + "</div>";
            html = html + "</article>";
        }
        html = html + "</div></div></section>";
        return html;
    }

    fn timeline(steps) {
        let html = "";
        html = html + "<section class='timeline'><div class='wrap panel reveal'><h2>Release Timeline</h2><ul class='timeline-list'>";
        for (s in steps) {
            html = html + "<li class='timeline-item'><div><strong>" + s.title + "</strong> ";
            html = html + "<span class='timeline-score'>" + s.score + "</span></div>";
            html = html + "<div>" + s.detail + "</div></li>";
        }
        html = html + "</ul></div></section>";
        return html;
    }
}
