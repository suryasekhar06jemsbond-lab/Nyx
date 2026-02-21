# ============================================================
# NYUI Framework Example
# ============================================================
# Demonstrates the new Native UI Framework features:
# - View DSL (declarative HTML-like syntax)
# - Reactive components
# - Event binding
# - Router DSL
# - Form & data binding

# Import NYUI module
let nyui = require("nyui");

# ============================================================
# COMPONENT EXAMPLE: Student Card
# ============================================================

# Define a StudentCard component
fn StudentCard(student: Map) -> VNode {
    return div({"class": "student-card"}, [
        h2({}, [text(student.get("full_name"))]),
        p({}, [text("Grade: " + (student.get("grade_applied") as String)]),
        p({}, [text("Email: " + student.get("email"))]),
        button({
            "class": "btn-apply",
            "onClick": fn(event: Event) {
                io.println("Applied for: " + student.get("full_name"));
            }
        }, [text("View Application")])
    ]);
}

# ============================================================
# REACTIVE EXAMPLE: Counter
# ============================================================

# Create a reactive counter
let count = Reactive::new(0);

fn CounterView() -> VNode {
    return div({"class": "counter"}, [
        h1({}, [text("Counter: " + (count.value as String)]),
        button({
            "onClick": fn(event: Event) {
                count.set(count.value + 1);
            }
        }, [text("Increment")]),
        button({
            "onClick": fn(event: Event) {
                count.set(count.value - 1);
            }
        }, [text("Decrement")])
    ]);
}

# ============================================================
# ROUTER EXAMPLE
# ============================================================

# Create a router
let router = Router::new();

# Define routes
router.get("/", fn(params: Map) -> VNode {
    return div({"class": "home"}, [
        h1({}, [text("Welcome to Nyx UI!")]),
        p({}, [text("This is a native UI framework built with Nyx.")]),
        a({"href": "/about"}, [text("About")])
    ]);
});

router.get("/about", fn(params: Map) -> VNode {
    return div({"class": "about"}, [
        h1({}, [text("About")]),
        p({}, [text("NYUI - Native UI Framework for Nyx")]),
        a({"href": "/"}, [text("Home")])
    ]);
});

router.get("/students", fn(params: Map) -> VNode {
    # Sample students
    let students = [
        {"full_name": "Alice Smith", "grade_applied": 1, "email": "alice@school.edu"},
        {"full_name": "Bob Johnson", "grade_applied": 3, "email": "bob@school.edu"},
        {"full_name": "Charlie Brown", "grade_applied": 5, "email": "charlie@school.edu"}
    ];
    
    return div({"class": "students-page"}, [
        h1({}, [text("Students")]),
        div({"class": "student-list"}, [
            StudentCard(student) for student in students
        ])
    ]);
});

# ============================================================
# FORM EXAMPLE
# ============================================================

# Create a form
let applicationForm = Form::new();

# Add form fields
applicationForm.field("first_name", "");
applicationForm.field("last_name", "");
applicationForm.field("email", "");
applicationForm.field("grade_applied", 1);

# Set validation
applicationForm.field("first_name", "").validate(fn(value: String) -> String {
    if (value as String).len() == 0 {
        return "First name is required";
    }
    return "";
});

applicationForm.field("email", "").validate(fn(value: String) -> String {
    if (value as String).len() == 0 {
        return "Email is required";
    }
    return "";
});

# Set submit handler
applicationForm.onSubmit(fn(data: Map) -> Any {
    io.println("Form submitted!");
    io.println("Data: " + (data as String));
});

fn ApplicationForm() -> VNode {
    return form({"class": "application-form", "onSubmit": fn(event: Event) {
        applicationForm.submit();
    }}, [
        h2({}, [text("Student Application")]),
        
        div({"class": "form-group"}, [
            label({}, [text("First Name")]),
            input({
                "type": "text",
                "value": applicationForm.fields.get("first_name").value.value,
                "onInput": fn(event: Event) {
                    applicationForm.fields.get("first_name").value.set(event.props.get("value"));
                }
            }),
            text(applicationForm.fields.get("first_name").error.value)
        ]),
        
        div({"class": "form-group"}, [
            label({}, [text("Last Name")]),
            input({
                "type": "text",
                "value": applicationForm.fields.get("last_name").value.value
            })
        ]),
        
        div({"class": "form-group"}, [
            label({}, [text("Email")]),
            input({
                "type": "email",
                "value": applicationForm.fields.get("email").value.value
            })
        ]),
        
        div({"class": "form-group"}, [
            label({}, [text("Grade")]),
            select({}, [
                option({"value": "1"}, [text("Grade 1")]),
                option({"value": "2"}, [text("Grade 2")]),
                option({"value": "3"}, [text("Grade 3")]),
                option({"value": "4"}, [text("Grade 4")]),
                option({"value": "5"}, [text("Grade 5")])
            ])
        ]),
        
        button({"type": "submit"}, [text("Submit Application")])
    ]);
}

# ============================================================
# MAIN PAGE - Full UI Example
# ============================================================

fn renderApp() -> VNode {
    return html({"lang": "en"}, [
        head({}, [
            meta({"charset": "UTF-8"}),
            meta({"name": "viewport", "content": "width=device-width, initial-scale=1.0"}),
            title({}, [text("Nyx UI Demo")]),
            style({}, [text("
                body { 
                    font-family: Arial, sans-serif; 
                    margin: 0; 
                    padding: 20px; 
                    background: #f5f5f5; 
                }
                .container { 
                    max-width: 800px; 
                    margin: 0 auto; 
                    background: white; 
                    padding: 30px; 
                    border-radius: 10px;
                }
                h1 { color: #2c3e50; }
                .btn-apply {
                    background: #3498db;
                    color: white;
                    padding: 10px 20px;
                    border: none;
                    border-radius: 5px;
                    cursor: pointer;
                }
                .student-card {
                    background: #ecf0f1;
                    padding: 20px;
                    margin: 10px 0;
                    border-radius: 8px;
                }
                .form-group {
                    margin: 15px 0;
                }
                label {
                    display: block;
                    margin-bottom: 5px;
                    font-weight: bold;
                }
                input, select {
                    width: 100%;
                    padding: 10px;
                    border: 1px solid #ddd;
                    border-radius: 5px;
                }
            "])
        ]),
        body({}, [
            div({"class": "container"}, [
                nav({}, [
                    a({"href": "/"}, [text("Home")]),
                    a({"href": "/students"}, [text("Students")]),
                    a({"href": "/apply"}, [text("Apply")])
                ]),
                
                # Use router view
                router.view()
            ])
        ])
    ]);
}

# ============================================================
# SSR EXAMPLE
# ============================================================

fn renderSSR() -> String {
    # Create SSR renderer
    let ssr = SSR::new(null);
    ssr.router = router;
    
    # Render page
    return ssr.renderPage("/students", {
        "title": "Nyx UI - Student List",
        "styles": "<style>body { background: #fff; }</style>",
        "scripts": "<script src=\"/bundle.js\"></script>"
    });
}

# Run the demo
io.println("=== NYUI Framework Demo ===");
io.println("");
io.println("Rendering application...");
io.println("");

let app = renderApp();
io.println(app.toHtml());

io.println("");
io.println("=== SSR Render ===");
io.println("");
io.println(renderSSR());

io.println("");
io.println("Demo complete!");
