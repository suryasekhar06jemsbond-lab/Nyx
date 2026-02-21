# NyWeb Full Website - Pure Nyx Syntax
# A complete website using NyWeb framework with VNode components
# No HTML strings - only Nyx UI DSL

import nyweb
import nyweb.vdom

# =============================================================================
# WEBSITE CONFIGURATION
# =============================================================================

let site_name = "NyWeb Framework"
let site_tagline = "Build Modern Web Apps in Nyx"
let server_host = "localhost"
let server_port = 8080

# =============================================================================
# STYLE DEFINITIONS (Nyx Style DSL)
# =============================================================================

let styles = nyui.StyleSheet.new()

# Global styles
styles.global({
    margin: "0",
    padding: "0",
    boxSizing: "border-box"
})

styles.body({
    fontFamily: "'Segoe UI', Tahoma, sans-serif",
    background: "linear-gradient(135deg, #1a1a2e 0%, #16213e 100%)",
    color: "#eee",
    minHeight: "100vh"
})

styles.class("container", {
    maxWidth: "1200px",
    margin: "0 auto",
    padding: "40px 20px"
})

styles.class("header", {
    textAlign: "center",
    marginBottom: "60px"
})

styles.class("title", {
    fontSize: "3.5em",
    color: "#e94560",
    textShadow: "0 0 30px rgba(233, 69, 96, 0.5)",
    marginBottom: "15px"
})

styles.class("subtitle", {
    fontSize: "1.5em",
    color: "#4ecdc4"
})

styles.class("nav", {
    display: "flex",
    justifyContent: "center",
    gap: "20px",
    marginTop: "30px"
})

styles.class("nav-link", {
    padding: "12px 30px",
    background: "#e94560",
    color: "#fff",
    textDecoration: "none",
    borderRadius: "25px",
    transition: "all 0.3s ease"
})

styles.class("hero", {
    background: "rgba(255, 255, 255, 0.05)",
    padding: "60px",
    borderRadius: "20px",
    textAlign: "center",
    border: "1px solid rgba(255, 255, 255, 0.1)",
    marginBottom: "40px"
})

styles.class("hero-title", {
    fontSize: "2.5em",
    color: "#fff",
    marginBottom: "20px"
})

styles.class("hero-text", {
    fontSize: "1.2em",
    color: "#aaa",
    lineHeight: "1.8",
    maxWidth: "800px",
    margin: "0 auto"
})

styles.class("features-grid", {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))",
    gap: "30px",
    margin: "50px 0"
})

styles.class("feature-card", {
    background: "rgba(255, 255, 255, 0.05)",
    padding: "35px",
    borderRadius: "15px",
    border: "1px solid rgba(255, 255, 255, 0.1)",
    transition: "all 0.3s ease"
})

styles.class("feature-title", {
    fontSize: "1.4em",
    color: "#e94560",
    marginBottom: "15px"
})

styles.class("feature-text", {
    color: "#aaa",
    lineHeight: "1.7"
})

styles.class("stats-row", {
    display: "flex",
    justifyContent: "space-around",
    flexWrap: "wrap",
    gap: "30px",
    padding: "40px",
    background: "rgba(233, 69, 96, 0.1)",
    borderRadius: "15px",
    margin: "40px 0"
})

styles.class("stat-item", {
    textAlign: "center"
})

styles.class("stat-number", {
    fontSize: "3em",
    color: "#e94560",
    fontWeight: "bold"
})

styles.class("stat-label", {
    color: "#888",
    marginTop: "10px"
})

styles.class("cta-section", {
    textAlign: "center",
    margin: "60px 0"
})

styles.class("btn-primary", {
    display: "inline-block",
    padding: "18px 50px",
    background: "#e94560",
    color: "#fff",
    border: "none",
    borderRadius: "30px",
    fontSize: "1.2em",
    cursor: "pointer",
    transition: "all 0.3s ease"
})

styles.class("footer", {
    textAlign: "center",
    padding: "40px",
    marginTop: "60px",
    borderTop: "1px solid rgba(255, 255, 255, 0.1)",
    color: "#666"
})

# =============================================================================
# UI COMPONENTS (VNode-based)
# =============================================================================

# Navigation Link Component
fn NavLink(href: String, text: String) -> VNode {
    return VNode.new("a")
        .attr("href", href)
        .attr("class", "nav-link")
        .child(VNode.text(text))
}

# Feature Card Component
fn FeatureCard(title: String, description: String, icon: String) -> VNode {
    return VNode.new("div")
        .attr("class", "feature-card")
        .child(VNode.new("h3").attr("class", "feature-title").child(VNode.text(icon + " " + title)))
        .child(VNode.new("p").attr("class", "feature-text").child(VNode.text(description)))
}

# Stat Item Component
fn StatItem(number: String, label: String) -> VNode {
    return VNode.new("div")
        .attr("class", "stat-item")
        .child(VNode.new("div").attr("class", "stat-number").child(VNode.text(number)))
        .child(VNode.new("div").attr("class", "stat-label").child(VNode.text(label)))
}

# Button Component
fn Button(text: String, onClick: fn()) -> VNode {
    return VNode.new("button")
        .attr("class", "btn-primary")
        .on("click", onClick)
        .child(VNode.text(text))
}

# =============================================================================
# PAGE LAYOUT
# =============================================================================

# Header Section
fn Header() -> VNode {
    return VNode.new("header")
        .attr("class", "header")
        .child(VNode.new("h1").attr("class", "title").child(VNode.text(site_name)))
        .child(VNode.new("p").attr("class", "subtitle").child(VNode.text(site_tagline)))
        .child(VNode.new("nav").attr("class", "nav")
            .child(NavLink("#home", "Home"))
            .child(NavLink("#features", "Features"))
            .child(NavLink("#docs", "Docs"))
            .child(NavLink("#demo", "Demo"))
        )
}

# Hero Section
fn Hero() -> VNode {
    return VNode.new("section")
        .attr("class", "hero")
        .attr("id", "home")
        .child(VNode.new("h2").attr("class", "hero-title").child(VNode.text("Build Modern Web Apps in Nyx")))
        .child(VNode.new("p").attr("class", "hero-text").child(VNode.text(
            "A complete full-stack framework with HTTP server, ORM, authentication, " +
            "reactive UI components, and frontend compiler. Write everything in pure Nyx syntax."
        )))
}

# Features Section
fn Features() -> VNode {
    return VNode.new("section")
        .attr("id", "features")
        .child(VNode.new("h2").attr("class", "title").child(VNode.text("Framework Features")))
        .child(VNode.new("div").attr("class", "features-grid")
            .child(FeatureCard("HTTP Server", "Built-in async server with routing, middleware, and WebSocket support.", "⚡"))
            .child(FeatureCard("ORM Database", "SQLite integration with migrations, models, and query builder.", "🗄️"))
            .child(FeatureCard("Authentication", "Secure sessions, bcrypt hashing, CSRF protection.", "🔐"))
            .child(FeatureCard("UI Components", "Reactive components with Virtual DOM and SSR support.", "🎨"))
            .child(FeatureCard("Frontend Compiler", "Compile to JavaScript/WASM with hot reload support.", "📦"))
            .child(FeatureCard("Production Ready", "Rate limiting, caching, logging, and error handling.", "🚀"))
        )
}

# Stats Section
fn Stats() -> VNode {
    return VNode.new("div")
        .attr("class", "stats-row")
        .child(StatItem("100%", "Nyx Code"))
        .child(StatItem("0", "Dependencies"))
        .child(StatItem("Fast", "Performance"))
        .child(StatItem("Full", "Stack"))
}

# Call to Action Section
fn CallToAction() -> VNode {
    return VNode.new("section")
        .attr("class", "cta-section")
        .attr("id", "demo")
        .child(Button("Get Started", fn() {
            print("Get Started clicked!")
        }))
}

# Footer Section
fn Footer() -> VNode {
    return VNode.new("footer")
        .attr("class", "footer")
        .child(VNode.new("p").child(VNode.text("NyWeb Framework - Built with ❤️ in Nyx Language")))
        .child(VNode.new("p").child(VNode.text("© 2026 Surya Sekhar Roy. All Rights Reserved.")))
}

# Main Page Layout
fn Page() -> VNode {
    return VNode.new("html")
        .child(VNode.new("head")
            .child(VNode.new("title").child(VNode.text(site_name)))
            .child(VNode.new("style").child(VNode.text(styles.render())))
        )
        .child(VNode.new("body")
            .child(VNode.new("div").attr("class", "container")
                .child(Header())
                .child(Hero())
                .child(Stats())
                .child(Features())
                .child(CallToAction())
                .child(Footer())
            )
        )
}

# =============================================================================
# APPLICATION SETUP
# =============================================================================

print("===========================================")
print("  " + site_name)
print("  " + site_tagline)
print("===========================================")
print("")

# Create the web application
let app = nyweb.Application.new(site_name)

# Configure application
app.debug = true
app.templates_dir = "./templates"
app.static_dir = "./static"

# Home route - renders the Page component
app.get("/") -> fn(request) {
    let page = Page()
    let html = nyui.render_to_string(page)
    return nyweb.Response.html(200, html)
}

# API status route
app.get("/api/status") -> fn(request) {
    return nyweb.Response.json(200, {
        status: "ok",
        framework: "NyWeb",
        version: "1.0.0",
        features: ["http-server", "orm", "auth", "vdom", "compiler"]
    })
}

# Features API route
app.get("/api/features") -> fn(request) {
    return nyweb.Response.json(200, {
        features: [
            { name: "HTTP Server", icon: "⚡", description: "Async server with routing" },
            { name: "ORM Database", icon: "🗄️", description: "SQLite integration" },
            { name: "Authentication", icon: "🔐", description: "Secure sessions" },
            { name: "UI Components", icon: "🎨", description: "Virtual DOM" },
            { name: "Compiler", icon: "📦", description: "JS/WASM output" },
            { name: "Production", icon: "🚀", description: "Full featured" }
        ]
    })
}

# =============================================================================
# START SERVER
# =============================================================================

print("Starting " + site_name + "...")
print("Server: http://" + server_host + ":" + server_port)
print("")
print("Routes:")
print("  GET /              - Home page")
print("  GET /api/status    - API status")
print("  GET /api/features  - Features list")
print("")
print("Press Ctrl+C to stop the server")
print("")

app.run(server_host, server_port)
