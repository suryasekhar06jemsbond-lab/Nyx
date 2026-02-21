# ============================================================
# SCHOOL ADMISSION SYSTEM - Pure Nyx Stack
# ============================================================
# A complete school admission website using pure Nyx
# No HTML, JS, or Python - 100% Nyx!
#
# Features:
# - Student registration
# - Application management
# - Admission status tracking
# - Admin dashboard

let VERSION = "1.0.0";

# ============================================================
# DATA MODELS
# ============================================================

# Student Application
pub class Student {
    pub let id: String;
    pub let first_name: String;
    pub let last_name: String;
    pub let email: String;
    pub let phone: String;
    pub let date_of_birth: String;
    pub let address: String;
    pub let grade_applied: Int;
    pub let guardian_name: String;
    pub let guardian_phone: String;
    pub let status: AdmissionStatus;
    pub let applied_date: Int;
    pub let notes: String;
    
    pub fn new(
        first_name: String,
        last_name: String,
        email: String,
        grade_applied: Int
    ) -> Self {
        return Self {
            id: generate_id(),
            first_name: first_name,
            last_name: last_name,
            email: email,
            phone: "",
            date_of_birth: "",
            address: "",
            grade_applied: grade_applied,
            guardian_name: "",
            guardian_phone: "",
            status: AdmissionStatus::Pending,
            applied_date: current_time_ms(),
            notes: ""
        };
    }
    
    pub fn full_name(self) -> String {
        return self.first_name + " " + self.last_name;
    }
    
    pub fn to_map(self) -> Map {
        return {
            "id": self.id,
            "first_name": self.first_name,
            "last_name": self.last_name,
            "email": self.email,
            "phone": self.phone,
            "date_of_birth": self.date_of_birth,
            "address": self.address,
            "grade_applied": self.grade_applied,
            "guardian_name": self.guardian_name,
            "guardian_phone": self.guardian_phone,
            "status": self.status as String,
            "applied_date": self.applied_date,
            "notes": self.notes
        };
    }
}

pub enum AdmissionStatus {
    Pending,
    UnderReview,
    Approved,
    Rejected,
    Waitlisted
}

# Grade/Class information
pub class Grade {
    pub let id: Int;
    pub let name: String;
    pub let capacity: Int;
    pub let enrolled: Int;
    pub let fees: Float;
    
    pub fn new(id: Int, name: String, capacity: Int, fees: Float) -> Self {
        return Self {
            id: id,
            name: name,
            capacity: capacity,
            enrolled: 0,
            fees: fees
        };
    }
    
    pub fn available_seats(self) -> Int {
        return self.capacity - self.enrolled;
    }
    
    pub fn is_full(self) -> Bool {
        return self.enrolled >= self.capacity;
    }
}

# ============================================================
# DATA STORE (In-Memory Database)
# ============================================================

pub class SchoolDatabase {
    pub let students: Map<String, Student>;
    pub let grades: Map<Int, Grade>;
    pub let applications: List<String>;
    
    pub fn new() -> Self {
        return Self {
            students: {},
            grades: {},
            applications: []
        };
    }
    
    # Initialize with grade data
    pub fn init_grades(self) {
        self.grades[1] = Grade::new(1, "Grade 1", 30, 5000.0);
        self.grades[2] = Grade::new(2, "Grade 2", 30, 5500.0);
        self.grades[3] = Grade::new(3, "Grade 3", 30, 6000.0);
        self.grades[4] = Grade::new(4, "Grade 4", 25, 6500.0);
        self.grades[5] = Grade::new(5, "Grade 5", 25, 7000.0);
        self.grades[6] = Grade::new(6, "Grade 6", 25, 7500.0);
        self.grades[7] = Grade::new(7, "Grade 7", 20, 8000.0);
        self.grades[8] = Grade::new(8, "Grade 8", 20, 8500.0);
        self.grades[9] = Grade::new(9, "Grade 9", 20, 9000.0);
        self.grades[10] = Grade::new(10, "Grade 10", 20, 10000.0);
    }
    
    # Add student application
    pub fn add_application(self, student: Student) -> String {
        self.students[student.id] = student;
        self.applications.push(student.id);
        
        # Increment grade enrollment
        if self.grades.has(student.grade_applied) {
            self.grades[student.grade_applied].enrolled = 
                self.grades[student.grade_applied].enrolled + 1;
        }
        
        return student.id;
    }
    
    # Get student by ID
    pub fn get_student(self, id: String) -> Student? {
        return self.students.get(id);
    }
    
    # Get all students
    pub fn get_all_students(self) -> List<Student> {
        return self.students.values();
    }
    
    # Get students by status
    pub fn get_students_by_status(self, status: AdmissionStatus) -> List<Student> {
        let result: List<Student> = [];
        for student in self.students.values() {
            if student.status == status {
                result.push(student);
            }
        }
        return result;
    }
    
    # Update admission status
    pub fn update_status(self, student_id: String, status: AdmissionStatus, notes: String) -> Bool {
        if not self.students.has(student_id) {
            return false;
        }
        
        self.students[student_id].status = status;
        self.students[student_id].notes = notes;
        return true;
    }
    
    # Get grade info
    pub fn get_grade(self, grade_id: Int) -> Grade? {
        return self.grades.get(grade_id);
    }
    
    # Get all grades
    pub fn get_all_grades(self) -> List<Grade> {
        return self.grades.values();
    }
    
    # Statistics
    pub fn get_stats(self) -> Map {
        let total = len(self.students);
        let pending = len(self.get_students_by_status(AdmissionStatus::Pending));
        let approved = len(self.get_students_by_status(AdmissionStatus::Approved));
        let rejected = len(self.get_students_by_status(AdmissionStatus::Rejected));
        
        return {
            "total_applications": total,
            "pending": pending,
            "approved": approved,
            "rejected": rejected,
            "waitlisted": len(self.get_students_by_status(AdmissionStatus::Waitlisted))
        };
    }
}

# ============================================================
# WEB ROUTER (Pure Nyx)
# ============================================================

pub class Router {
    pub let routes: Map<String, fn(Map) -> Map>;
    
    pub fn new() -> Self {
        return Self { routes: {} };
    }
    
    pub fn get(self, path: String, handler: fn(Map) -> Map) {
        self.routes["GET " + path] = handler;
    }
    
    pub fn post(self, path: String, handler: fn(Map) -> Map) {
        self.routes["POST " + path] = handler;
    }
    
    pub fn put(self, path: String, handler: fn(Map) -> Map) {
        self.routes["PUT " + path] = handler;
    }
    
    pub fn delete(self, path: String, handler: fn(Map) -> Map) {
        self.routes["DELETE " + path] = handler;
    }
    
    pub fn handle(self, method: String, path: String, request: Map) -> Map {
        let key = method + " " + path;
        
        if self.routes.has(key) {
            return self.routes[key](request);
        }
        
        # Try wildcard matching
        for route_key in self.routes.keys() {
            if route_key.contains("*") {
                let pattern = route_key.replace("*", "");
                if path.starts_with(pattern) {
                    return self.routes[route_key](request);
                }
            }
        }
        
        return {
            "status": 404,
            "body": {"error": "Not found"}
        };
    }
}

# ============================================================
# RESPONSE HELPERS
# ============================================================

pub fn json_response(data: Map, status: Int) -> Map {
    return {
        "status": status,
        "headers": {"Content-Type": "application/json"},
        "body": data
    };
}

pub fn success(data: Map) -> Map {
    return json_response({"success": true, "data": data}, 200);
}

pub fn error(message: String, status: Int) -> Map {
    return json_response({"success": false, "error": message}, status);
}

# ============================================================
# APPLICATION HANDLERS
# ============================================================

let db = SchoolDatabase::new();
db.init_grades();

# Home page - Show school info
fn handle_home(request: Map) -> Map {
    return success({
        "title": "Sunrise International School",
        "tagline": "Excellence in Education",
        "welcome": "Welcome to Sunrise International School Admission Portal",
        "academic_year": "2026-2027",
        "message": "Apply online for the upcoming academic year",
        "features": [
            "Online Application",
            "Quick Processing",
            "Transparent Status",
            "Secure Data"
        ]
    });
}

# List available grades
fn handle_grades(request: Map) -> Map {
    let grades = db.get_all_grades();
    let grade_list: List<Map> = [];
    
    for grade in grades {
        grade_list.push({
            "id": grade.id,
            "name": grade.name,
            "capacity": grade.capacity,
            "enrolled": grade.enrolled,
            "available": grade.available_seats(),
            "fees": grade.fees,
            "is_full": grade.is_full()
        });
    }
    
    return success({"grades": grade_list});
}

# Show admission form
fn handle_form(request: Map) -> Map {
    return success({
        "form_title": "Student Admission Application",
        "fields": [
            {"name": "first_name", "label": "First Name", "type": "text", "required": true},
            {"name": "last_name", "label": "Last Name", "type": "text", "required": true},
            {"name": "email", "label": "Email", "type": "email", "required": true},
            {"name": "phone", "label": "Phone", "type": "tel", "required": true},
            {"name": "date_of_birth", "label": "Date of Birth", "type": "date", "required": true},
            {"name": "address", "label": "Address", "type": "textarea", "required": true},
            {"name": "grade_applied", "label": "Grade Applied", "type": "select", "required": true},
            {"name": "guardian_name", "label": "Guardian Name", "type": "text", "required": true},
            {"name": "guardian_phone", "label": "Guardian Phone", "type": "tel", "required": true}
        ],
        "grades_available": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    });
}

# Submit application
fn handle_submit(request: Map) -> Map {
    let body = request.get("body") as Map?;
    
    if body == null {
        return error("Missing request body", 400);
    }
    
    # Validate required fields
    let required = ["first_name", "last_name", "email", "grade_applied"];
    for field in required {
        if not body.has(field) {
            return error("Missing required field: " + field, 400);
        }
    }
    
    # Create student
    let student = Student::new(
        body["first_name"] as String,
        body["last_name"] as String,
        body["email"] as String,
        body["grade_applied"] as Int
    );
    
    # Optional fields
    if body.has("phone") { student.phone = body["phone"] as String; }
    if body.has("date_of_birth") { student.date_of_birth = body["date_of_birth"] as String; }
    if body.has("address") { student.address = body["address"] as String; }
    if body.has("guardian_name") { student.guardian_name = body["guardian_name"] as String; }
    if body.has("guardian_phone") { student.guardian_phone = body["guardian_phone"] as String; }
    
    # Check grade availability
    let grade = db.get_grade(student.grade_applied);
    if grade != null and grade.is_full() {
        student.status = AdmissionStatus::Waitlisted;
    }
    
    # Save application
    let id = db.add_application(student);
    
    return success({
        "message": "Application submitted successfully!",
        "application_id": id,
        "status": student.status as String,
        "next_steps": [
            "Check your email for confirmation",
            "Track your application status using your ID",
            "Visit the school for document verification"
        ]
    });
}

# Check application status
fn handle_status(request: Map) -> Map {
    let body = request.get("body") as Map?;
    
    if body == null or not body.has("application_id") {
        return error("Application ID required", 400);
    }
    
    let student_id = body["application_id"] as String;
    let student = db.get_student(student_id);
    
    if student == null {
        return error("Application not found", 404);
    }
    
    return success({
        "application_id": student.id,
        "student_name": student.full_name(),
        "grade_applied": student.grade_applied,
        "status": student.status as String,
        "applied_date": student.applied_date,
        "notes": student.notes
    });
}

# Admin: List all applications
fn handle_admin_list(request: Map) -> Map {
    let students = db.get_all_students();
    let list: List<Map> = [];
    
    for student in students {
        list.push({
            "id": student.id,
            "name": student.full_name(),
            "email": student.email,
            "grade": student.grade_applied,
            "status": student.status as String,
            "applied_date": student.applied_date
        });
    }
    
    return success({"applications": list});
}

# Admin: Update application status
fn handle_admin_update(request: Map) -> Map {
    let body = request.get("body") as Map?;
    
    if body == null {
        return error("Missing request body", 400);
    }
    
    let id = body.get("application_id") as String?;
    let status_str = body.get("status") as String?;
    let notes = body.get("notes") as String? or "";
    
    if id == null or status_str == null {
        return error("Application ID and status required", 400);
    }
    
    # Parse status
    let status = AdmissionStatus::Pending;
    if status_str == "UnderReview" { status = AdmissionStatus::UnderReview; }
    else if status_str == "Approved" { status = AdmissionStatus::Approved; }
    else if status_str == "Rejected" { status = AdmissionStatus::Rejected; }
    else if status_str == "Waitlisted" { status = AdmissionStatus::Waitlisted; }
    
    let result = db.update_status(id, status, notes);
    
    if result {
        return success({"message": "Status updated successfully"});
    }
    
    return error("Application not found", 404);
}

# Admin: Dashboard stats
fn handle_admin_stats(request: Map) -> Map {
    return success(db.get_stats());
}

# ============================================================
# ROUTER SETUP
# ============================================================

let router = Router::new();

# Public routes
router.get("/", handle_home);
router.get("/grades", handle_grades);
router.get("/apply", handle_form);
router.post("/apply", handle_submit);
router.post("/status", handle_status);

# Admin routes
router.get("/admin/applications", handle_admin_list);
router.post("/admin/update", handle_admin_update);
router.get("/admin/stats", handle_admin_stats);

# ============================================================
# SERVER SIMULATION
# ============================================================

# Simulate HTTP request
pub fn handle_request(method: String, path: String, body: Map?) -> Map {
    let request = {"method": method, "path": path, "body": body};
    return router.handle(method, path, request);
}

# ============================================================
# MAIN - DEMO
# ============================================================

pub fn main() {
    io.println("========================================");
    io.println("School Admission System");
    io.println("Pure Nyx Stack - No HTML/JS/Python!");
    io.println("========================================");
    io.println("");
    
    # Demo: View home page
    io.println("1. HOME PAGE");
    io.println("----------");
    let response = handle_request("GET", "/", null);
    io.println(response as String);
    io.println("");
    
    # Demo: View grades
    io.println("2. AVAILABLE GRADES");
    io.println("-----------------");
    response = handle_request("GET", "/grades", null);
    io.println(response as String);
    io.println("");
    
    # Demo: Submit application
    io.println("3. SUBMIT APPLICATION");
    io.println("--------------------");
    let application = {
        "first_name": "John",
        "last_name": "Smith",
        "email": "john.smith@email.com",
        "phone": "+1234567890",
        "date_of_birth": "2015-05-15",
        "address": "123 Main Street, City",
        "grade_applied": 5,
        "guardian_name": "Jane Smith",
        "guardian_phone": "+0987654321"
    };
    response = handle_request("POST", "/apply", application);
    io.println(response as String);
    io.println("");
    
    # Get the application ID from response
    let app_id = "demo-id-123";
    
    # Demo: Check status
    io.println("4. CHECK APPLICATION STATUS");
    io.println("-------------------------");
    response = handle_request("POST", "/status", {"application_id": app_id});
    io.println(response as String);
    io.println("");
    
    # Demo: Admin stats
    io.println("5. ADMIN DASHBOARD STATS");
    io.println("------------------------");
    response = handle_request("GET", "/admin/stats", null);
    io.println(response as String);
    io.println("");
    
    io.println("========================================");
    io.println("API ENDPOINTS");
    io.println("========================================");
    io.println("");
    io.println("Public:");
    io.println("  GET  /             - Home page info");
    io.println("  GET  /grades       - Available grades");
    io.println("  GET  /apply        - Application form");
    io.println("  POST /apply        - Submit application");
    io.println("  POST /status       - Check status");
    io.println("");
    io.println("Admin:");
    io.println("  GET  /admin/applications - List all");
    io.println("  POST /admin/update       - Update status");
    io.println("  GET  /admin/stats       - Dashboard");
    io.println("");
    io.println("========================================");
    io.println("TO RUN WITH NYWEB:");
    io.println("========================================");
    io.println("");
    io.println('  use NyWeb;');
    io.println('  let app = NyWeb.Application.new("SchoolAdmission");');
    io.println('  app.mount_router(router);');
    io.println('  app.run("localhost", 8080);');
    io.println("");
}

# Run main
main();
