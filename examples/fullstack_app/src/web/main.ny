# ╔══════════════════════════════════════════════════════════════════╗
# ║                  FRONTEND WEB APP (Pure Nyx!)                    ║
# ║              Replaces: React, HTML, CSS, TypeScript              ║
# ╚══════════════════════════════════════════════════════════════════╝

import nyui
import shared.models as models
import shared.api as api

# ═══════════════════════════════════════════════════════════════════
# MAIN APP COMPONENT
# ═══════════════════════════════════════════════════════════════════

class App : Component {
    state: AppState
    
    fn init(self) {
        self.state = AppState {
            users: [],
            loading: true,
            error: None
        }
        
        # Load users on mount
        self.load_users()
    }
    
    async fn load_users(self) {
        self.set_state({ loading: true })
        
        match await api.get_users() {
            Ok(users) => {
                self.set_state({
                    users: users,
                    loading: false
                })
            }
            Err(e) => {
                self.set_state({
                    error: Some(e),
                    loading: false
                })
            }
        }
    }
    
    fn render(self) -> Element {
        return div {
            class: "app"
            
            # Header
            header {
                class: "header"
                style: {
                    background: "#2c3e50"
                    color: "white"
                    padding: "20px"
                }
                
                h1 { "User Management System" }
                p { "Built entirely in Nyx - No JavaScript!" }
            }
            
            # Main content
            main {
                class: "container"
                style: {
                    max_width: "1200px"
                    margin: "0 auto"
                    padding: "20px"
                }
                
                # Loading state
                if self.state.loading {
                    Spinner { message: "Loading users..." }
                }
                
                # Error state
                if let Some(error) = self.state.error {
                    Alert {
                        type: "error"
                        message: error
                    }
                }
                
                # User list
                if !self.state.loading && self.state.error.is_none() {
                    UserList {
                        users: self.state.users
                        on_delete: |id| self.delete_user(id)
                        on_edit: |user| self.show_edit_dialog(user)
                    }
                }
                
                # Add user button
                Button {
                    text: "Add New User"
                    style: {
                        background: "#3498db"
                        color: "white"
                        padding: "10px 20px"
                        border_radius: "5px"
                    }
                    on_click: || self.show_add_dialog()
                }
            }
        }
    }
    
    async fn delete_user(self, id: i64) {
        match await api.delete_user(id) {
            Ok(_) => self.load_users(),
            Err(e) => self.set_state({ error: Some(e) })
        }
    }
    
    fn show_add_dialog(self) {
        # Show dialog component
        Dialog.show(AddUserForm {
            on_save: |user| self.add_user(user)
        })
    }
    
    fn show_edit_dialog(self, user: models.User) {
        Dialog.show(EditUserForm {
            user: user
            on_save: |updated| self.update_user(updated)
        })
    }
}

# ═══════════════════════════════════════════════════════════════════
# USER LIST COMPONENT
# ═══════════════════════════════════════════════════════════════════

class UserList : Component {
    props: {
        users: Vec<models.User>
        on_delete: fn(i64)
        on_edit: fn(models.User)
    }
    
    fn render(self) -> Element {
        return div {
            class: "user-list"
            
            # Header
            div {
                class: "list-header"
                style: {
                    display: "grid"
                    grid_template_columns: "1fr 2fr 2fr 1fr"
                    font_weight: "bold"
                    padding: "10px"
                    background: "#ecf0f1"
                }
                
                span { "ID" }
                span { "Name" }
                span { "Email" }
                span { "Actions" }
            }
            
            # User rows
            for user in self.props.users {
                UserRow {
                    user: user
                    on_delete: self.props.on_delete
                    on_edit: self.props.on_edit
                }
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════
# USER ROW COMPONENT
# ═══════════════════════════════════════════════════════════════════

class UserRow : Component {
    props: {
        user: models.User
        on_delete: fn(i64)
        on_edit: fn(models.User)
    }
    
    fn render(self) -> Element {
        let user = self.props.user
        
        return div {
            class: "user-row"
            style: {
                display: "grid"
                grid_template_columns: "1fr 2fr 2fr 1fr"
                padding: "10px"
                border_bottom: "1px solid #ddd"
            }
            
            span { "{user.id}" }
            span { "{user.name}" }
            span { "{user.email}" }
            
            div {
                class: "actions"
                
                Button {
                    text: "Edit"
                    size: "small"
                    on_click: || self.props.on_edit(user)
                }
                
                Button {
                    text: "Delete"
                    size: "small"
                    variant: "danger"
                    on_click: || self.props.on_delete(user.id)
                }
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════
# ADD USER FORM COMPONENT
# ═══════════════════════════════════════════════════════════════════

class AddUserForm : Component {
    props: {
        on_save: fn(models.User)
    }
    
    state: {
        name: String
        email: String
        errors: Map<String, String>
    }
    
    fn init(self) {
        self.state = {
            name: ""
            email: ""
            errors: {}
        }
    }
    
    fn validate(self) -> bool {
        let mut errors = {}
        
        if self.state.name.is_empty() {
            errors["name"] = "Name is required"
        }
        
        if !self.state.email.contains("@") {
            errors["email"] = "Invalid email address"
        }
        
        self.set_state({ errors: errors })
        return errors.is_empty()
    }
    
    async fn submit(self) {
        if !self.validate() {
            return
        }
        
        let user = models.User {
            id: 0,  # Will be set by backend
            name: self.state.name,
            email: self.state.email,
            created_at: DateTime.now()
        }
        
        match await api.create_user(user) {
            Ok(created) => {
                self.props.on_save(created)
                Dialog.close()
            }
            Err(e) => {
                self.set_state({
                    errors: { "form": e }
                })
            }
        }
    }
    
    fn render(self) -> Element {
        return form {
            class: "user-form"
            on_submit: |e| {
                e.prevent_default()
                self.submit()
            }
            
            h2 { "Add New User" }
            
            # Name field
            FormField {
                label: "Name"
                error: self.state.errors.get("name")
                
                Input {
                    type: "text"
                    value: self.state.name
                    on_change: |value| self.set_state({ name: value })
                    placeholder: "Enter name"
                }
            }
            
            # Email field
            FormField {
                label: "Email"
                error: self.state.errors.get("email")
                
                Input {
                    type: "email"
                    value: self.state.email
                    on_change: |value| self.set_state({ email: value })
                    placeholder: "Enter email"
                }
            }
            
            # Form error
            if let Some(error) = self.state.errors.get("form") {
                Alert {
                    type: "error"
                    message: error
                }
            }
            
            # Buttons
            div {
                class: "form-actions"
                
                Button {
                    text: "Cancel"
                    variant: "secondary"
                    on_click: || Dialog.close()
                }
                
                Button {
                    text: "Save"
                    type: "submit"
                    variant: "primary"
                }
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════
# REUSABLE COMPONENTS
# ═══════════════════════════════════════════════════════════════════

class Button : Component {
    props: {
        text: String
        on_click: fn()
        variant: String = "primary"
        size: String = "medium"
        type: String = "button"
    }
    
    fn render(self) -> Element {
        let colors = match self.props.variant {
            "primary" => { bg: "#3498db", hover: "#2980b9" }
            "secondary" => { bg: "#95a5a6", hover: "#7f8c8d" }
            "danger" => { bg: "#e74c3c", hover: "#c0392b" }
            _ => { bg: "#3498db", hover: "#2980b9" }
        }
        
        let padding = match self.props.size {
            "small" => "5px 10px"
            "medium" => "10px 20px"
            "large" => "15px 30px"
            _ => "10px 20px"
        }
        
        return button {
            type: self.props.type
            style: {
                background: colors.bg
                color: "white"
                padding: padding
                border: "none"
                border_radius: "5px"
                cursor: "pointer"
                font_size: "14px"
                transition: "background 0.3s"
            }
            on_click: self.props.on_click
            on_hover: |e| {
                e.target.style.background = colors.hover
            }
            
            "{self.props.text}"
        }
    }
}

class Spinner : Component {
    props: {
        message: String = "Loading..."
    }
    
    fn render(self) -> Element {
        return div {
            class: "spinner"
            style: {
                display: "flex"
                flex_direction: "column"
                align_items: "center"
                padding: "40px"
            }
            
            div {
                style: {
                    border: "4px solid #f3f3f3"
                    border_top: "4px solid #3498db"
                    border_radius: "50%"
                    width: "40px"
                    height: "40px"
                    animation: "spin 1s linear infinite"
                }
            }
            
            p {
                style: { margin_top: "20px", color: "#7f8c8d" }
                "{self.props.message}"
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════
# APP ENTRY POINT
# ═══════════════════════════════════════════════════════════════════

fn main() {
    # Mount app to DOM
    nyui.mount("#app", App)
    
    # Enable hot reload in development
    #[cfg(debug)]
    nyui.enable_hot_reload()
}

# ═══════════════════════════════════════════════════════════════════
# STYLING (CSS-in-Nyx!)
# ═══════════════════════════════════════════════════════════════════

global_styles {
    "*" {
        margin: 0
        padding: 0
        box_sizing: "border-box"
    }
    
    "body" {
        font_family: "Arial, sans-serif"
        background: "#f5f5f5"
    }
    
    "@keyframes spin" {
        "0%" { transform: "rotate(0deg)" }
        "100%" { transform: "rotate(360deg)" }
    }
}
