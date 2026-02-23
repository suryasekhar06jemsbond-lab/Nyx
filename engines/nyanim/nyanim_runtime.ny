module nyanim {
    fn motion_styles() {
        let css = "";
        css = css + ".reveal { opacity: 0; transform: translateY(18px) scale(0.985); }";
        css = css + ".reveal.in { opacity: 1; transform: translateY(0) scale(1); transition: opacity .65s ease, transform .65s cubic-bezier(.2,.7,.2,1); }";
        css = css + ".kpi:hover, .engine:hover, .panel:hover { border-color: rgba(248, 207, 97, 0.62); transform: translateY(-2px); transition: transform .2s ease, border-color .2s ease; }";
        css = css + ".scanline::after { content: ''; position: fixed; inset: 0; pointer-events: none; opacity: .07;";
        css = css + "background: linear-gradient(transparent 94%, rgba(255,255,255,.5) 95%, transparent 96%); background-size: 100% 6px; }";
        css = css + "@keyframes pulseGlow { 0% { box-shadow: 0 0 0 rgba(76,230,197,0); } 50% { box-shadow: 0 0 28px rgba(76,230,197,.35); } 100% { box-shadow: 0 0 0 rgba(76,230,197,0); } }";
        css = css + ".chip { animation: pulseGlow 3.2s ease-in-out infinite; }";
        return css;
    }

    fn motion_script() {
        let js = "";
        js = js + "(() => {";
        js = js + "const reveal = Array.from(document.querySelectorAll('.reveal'));";
        js = js + "const io = new IntersectionObserver((entries) => {";
        js = js + "for (const e of entries) { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }";
        js = js + "}, { threshold: 0.15 });";
        js = js + "for (const node of reveal) io.observe(node);";
        js = js + "const body = document.body;";
        js = js + "window.addEventListener('mousemove', (ev) => {";
        js = js + "const x = Math.round((ev.clientX / window.innerWidth) * 100);";
        js = js + "const y = Math.round((ev.clientY / window.innerHeight) * 100);";
        js = js + "body.style.backgroundPosition = x + '% ' + y + '%';";
        js = js + "}, { passive: true });";
        js = js + "})();";
        return js;
    }
}
