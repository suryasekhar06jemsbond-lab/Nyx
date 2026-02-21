# Advanced Interactive Calculator with GUI
# Built using Nyx nyagui library

# Import the GUI library
import nyagui

# Calculator class with all operations
class Calculator {
    fn init(self) {
        self.current = "0";
        self.previous = null;
        self.operator = null;
        self.memory = 0;
        self.history = [];
        self.should_clear = false;
    }
    
    # Basic operations
    fn add(self, a, b) = a + b
    fn subtract(self, a, b) = a - b
    fn multiply(self, a, b) = a * b
    fn divide(self, a, b) = {
        if b == 0 {
            "Error: Div by zero"
        } else {
            a / b
        }
    }
    
    # Advanced operations
    fn power(self, base, exp) = base ^ exp
    fn sqrt(self, n) = {
        if n < 0 {
            "Error: Negative"
        } else {
            n ^ 0.5
        }
    }
    fn sin(self, x) = {
        # Simplified sin approximation
        let result = 0
        for i in 0..10 {
            result = result + ((-1) ^ i * x ^ (2 * i + 1)) / self.factorial(2 * i + 1)
        }
        result
    }
    fn cos(self, x) = {
        # Simplified cos approximation  
        let result = 0
        for i in 0..10 {
            result = result + ((-1) ^ i * x ^ (2 * i)) / self.factorial(2 * i)
        }
        result
    }
    fn tan(self, x) = self.sin(x) / self.cos(x)
    fn log(self, n) = {
        if n <= 0 {
            "Error: Invalid"
        } else {
            self.ln(n) / 2.718281828
        }
    }
    fn ln(self, n) = {
        if n <= 0 {
            "Error: Invalid"
        } else {
            # Natural log approximation
            let x = (n - 1) / (n + 1)
            let result = 0
            for i in 0..50 {
                result = result + (2 * x ^ (2 * i + 1)) / (2 * i + 1)
            }
            result
        }
    }
    fn factorial(self, n) = {
        if n <= 1 {
            1
        } else {
            let result = 1
            for i in 2..=n {
                result = result * i
            }
            result
        }
    }
    
    # Memory functions
    fn memory_clear(self) {
        self.memory = 0
    }
    fn memory_recall(self) = self.memory
    fn memory_add(self, value) {
        self.memory = self.memory + value
    }
    fn memory_subtract(self, value) {
        self.memory = self.memory - value
    }
    
    # Display functions
    fn append_digit(self, digit) {
        if self.should_clear {
            self.current = digit
            self.should_clear = false
        } else if self.current == "0" {
            self.current = digit
        } else {
            self.current = self.current + digit
        }
        self.current
    }
    
    fn append_decimal(self) {
        if self.should_clear {
            self.current = "0."
            self.should_clear = false
        } else if self.current.contains(".") {
            self.current
        } else {
            self.current = self.current + "."
            self.current
        }
    }
    
    fn set_operator(self, op) {
        if self.previous != null {
            self.calculate()
        }
        self.previous = self.current
        self.operator = op
        self.should_clear = true
        self.current
    }
    
    fn calculate(self) = {
        if self.previous == null || self.operator == null {
            self.current
        } else {
            let a = self.parse_number(self.previous)
            let b = self.parse_number(self.current)
            let result = match self.operator {
                case "+" => self.add(a, b)
                case "-" => self.subtract(a, b)
                case "*" => self.multiply(a, b)
                case "/" => self.divide(a, b)
                case "^" => self.power(a, b)
                case _ => "Error"
            }
            
            # Add to history
            let entry = self.previous + " " + self.operator + " " + self.current + " = " + self.to_string(result)
            self.history.push(entry)
            
            self.previous = null
            self.operator = null
            self.current = self.to_string(result)
            self.should_clear = true
            self.current
        }
    }
    
    fn parse_number(self, s) = {
        if s.contains(".") {
            s.to_float()
        } else {
            s.to_int()
        }
    }
    
    fn to_string(self, n) = {
        if n.type() == "float" {
            if n == n.to_int() {
                n.to_int().to_string()
            } else {
                n.to_string()
            }
        } else {
            n.to_string()
        }
    }
    
    fn clear(self) {
        self.current = "0"
        self.previous = null
        self.operator = null
        self.should_clear = false
        "0"
    }
    
    fn backspace(self) = {
        if self.current.len() > 1 {
            self.current = self.current.substr(0, self.current.len() - 1)
        } else {
            self.current = "0"
        }
        self.current
    }
    
    fn toggle_sign(self) = {
        if self.current != "0" {
            if self.current.starts_with("-") {
                self.current = self.current.substr(1)
            } else {
                self.current = "-" + self.current
            }
        }
        self.current
    }
    
    fn percentage(self) = {
        let val = self.parse_number(self.current) / 100
        self.current = self.to_string(val)
        self.current
    }
}

# Build the GUI Calculator
fn create_calculator() {
    let calc = Calculator.new()
    
    # Create main window
    let window = nyagui.Window.new("Nyx Calculator", 400, 600)
    window.set_size(400, 600)
    
    # Display
    let display = nyagui.Entry.new(380)
    display.configure(text: "0")
    display.x = 10
    display.y = 10
    window.add_widget(display)
    
    # History display
    let history_label = nyagui.Label.new("History: ")
    history_label.x = 10
    history_label.y = 50
    window.add_widget(history_label)
    
    # Function to update display
    fn update_display(text) {
        display.set(text)
    }
    
    # Button click handlers
    fn on_digit(digit) {
        let result = calc.append_digit(digit)
        update_display(result)
    }
    
    fn on_operator(op) {
        let result = calc.set_operator(op)
        update_display(result)
    }
    
    fn on_equals() {
        let result = calc.calculate()
        update_display(result)
    }
    
    fn on_clear() {
        let result = calc.clear()
        update_display(result)
    }
    
    fn on_backspace() {
        let result = calc.backspace()
        update_display(result)
    }
    
    fn on_decimal() {
        let result = calc.append_decimal()
        update_display(result)
    }
    
    fn on_toggle_sign() {
        let result = calc.toggle_sign()
        update_display(result)
    }
    
    fn on_percentage() {
        let result = calc.percentage()
        update_display(result)
    }
    
    # Memory functions
    fn on_mc() {
        calc.memory_clear()
        update_display(calc.current)
    }
    
    fn on_mr() {
        let val = calc.memory_recall()
        calc.current = calc.to_string(val)
        update_display(calc.current)
    }
    
    fn on_m_plus() {
        let val = calc.parse_number(calc.current)
        calc.memory_add(val)
        update_display(calc.current)
    }
    
    fn on_m_minus() {
        let val = calc.parse_number(calc.current)
        calc.memory_subtract(val)
        update_display(calc.current)
    }
    
    # Advanced functions
    fn on_sqrt() {
        let val = calc.parse_number(calc.current)
        let result = calc.sqrt(val)
        calc.current = calc.to_string(result)
        update_display(calc.current)
    }
    
    fn on_sin() {
        let val = calc.parse_number(calc.current)
        let result = calc.sin(val)
        calc.current = calc.to_string(result)
        update_display(calc.current)
    }
    
    fn on_cos() {
        let val = calc.parse_number(calc.current)
        let result = calc.cos(val)
        calc.current = calc.to_string(result)
        update_display(calc.current)
    }
    
    fn on_tan() {
        let val = calc.parse_number(calc.current)
        let result = calc.tan(val)
        calc.current = calc.to_string(result)
        update_display(calc.current)
    }
    
    fn on_log() {
        let val = calc.parse_number(calc.current)
        let result = calc.log(val)
        calc.current = calc.to_string(result)
        update_display(calc.current)
    }
    
    fn on_factorial() {
        let val = calc.parse_number(calc.current)
        let result = calc.factorial(val)
        calc.current = calc.to_string(result)
        update_display(calc.current)
    }
    
    # Create button grid
    let button_y = 90
    let button_height = 45
    let button_width = 80
    let gap = 5
    
    # Row 1: Memory functions
    let btn_mc = nyagui.Button.new("MC", on_mc)
    btn_mc.x = 10
    btn_mc.y = button_y
    btn_mc.width = button_width
    btn_mc.height = button_height
    window.add_widget(btn_mc)
    
    let btn_mr = nyagui.Button.new("MR", on_mr)
    btn_mr.x = 10 + button_width + gap
    btn_mr.y = button_y
    btn_mr.width = button_width
    btn_mr.height = button_height
    window.add_widget(btn_mr)
    
    let btn_m_plus = nyagui.Button.new("M+", on_m_plus)
    btn_m_plus.x = 10 + 2 * (button_width + gap)
    btn_m_plus.y = button_y
    btn_m_plus.width = button_width
    btn_m_plus.height = button_height
    window.add_widget(btn_m_plus)
    
    let btn_m_minus = nyagui.Button.new("M-", on_m_minus)
    btn_m_minus.x = 10 + 3 * (button_width + gap)
    btn_m_minus.y = button_y
    btn_m_minus.width = button_width
    btn_m_minus.height = button_height
    window.add_widget(btn_m_minus)
    
    # Row 2: Advanced functions
    button_y = button_y + button_height + gap
    
    let btn_sqrt = nyagui.Button.new("√", on_sqrt)
    btn_sqrt.x = 10
    btn_sqrt.y = button_y
    btn_sqrt.width = button_width
    btn_sqrt.height = button_height
    window.add_widget(btn_sqrt)
    
    let btn_sin = nyagui.Button.new("sin", on_sin)
    btn_sin.x = 10 + button_width + gap
    btn_sin.y = button_y
    btn_sin.width = button_width
    btn_sin.height = button_height
    window.add_widget(btn_sin)
    
    let btn_cos = nyagui.Button.new("cos", on_cos)
    btn_cos.x = 10 + 2 * (button_width + gap)
    btn_cos.y = button_y
    btn_cos.width = button_width
    btn_cos.height = button_height
    window.add_widget(btn_cos)
    
    let btn_tan = nyagui.Button.new("tan", on_tan)
    btn_tan.x = 10 + 3 * (button_width + gap)
    btn_tan.y = button_y
    btn_tan.width = button_width
    btn_tan.height = button_height
    window.add_widget(btn_tan)
    
    # Row 3: More advanced
    button_y = button_y + button_height + gap
    
    let btn_log = nyagui.Button.new("log", on_log)
    btn_log.x = 10
    btn_log.y = button_y
    btn_log.width = button_width
    btn_log.height = button_height
    window.add_widget(btn_log)
    
    let btn_fact = nyagui.Button.new("n!", on_factorial)
    btn_fact.x = 10 + button_width + gap
    btn_fact.y = button_y
    btn_fact.width = button_width
    btn_fact.height = button_height
    window.add_widget(btn_fact)
    
    let btn_clear = nyagui.Button.new("C", on_clear)
    btn_clear.x = 10 + 2 * (button_width + gap)
    btn_clear.y = button_y
    btn_clear.width = button_width
    btn_clear.height = button_height
    window.add_widget(btn_clear)
    
    let btn_back = nyagui.Button.new("⌫", on_backspace)
    btn_back.x = 10 + 3 * (button_width + gap)
    btn_back.y = button_y
    btn_back.width = button_width
    btn_back.height = button_height
    window.add_widget(btn_back)
    
    # Row 4: 7, 8, 9, /
    button_y = button_y + button_height + gap
    
    let btn_7 = nyagui.Button.new("7", fn() { on_digit("7") })
    btn_7.x = 10
    btn_7.y = button_y
    btn_7.width = button_width
    btn_7.height = button_height
    window.add_widget(btn_7)
    
    let btn_8 = nyagui.Button.new("8", fn() { on_digit("8") })
    btn_8.x = 10 + button_width + gap
    btn_8.y = button_y
    btn_8.width = button_width
    btn_8.height = button_height
    window.add_widget(btn_8)
    
    let btn_9 = nyagui.Button.new("9", fn() { on_digit("9") })
    btn_9.x = 10 + 2 * (button_width + gap)
    btn_9.y = button_y
    btn_9.width = button_width
    btn_9.height = button_height
    window.add_widget(btn_9)
    
    let btn_div = nyagui.Button.new("/", fn() { on_operator("/") })
    btn_div.x = 10 + 3 * (button_width + gap)
    btn_div.y = button_y
    btn_div.width = button_width
    btn_div.height = button_height
    window.add_widget(btn_div)
    
    # Row 5: 4, 5, 6, *
    button_y = button_y + button_height + gap
    
    let btn_4 = nyagui.Button.new("4", fn() { on_digit("4") })
    btn_4.x = 10
    btn_4.y = button_y
    btn_4.width = button_width
    btn_4.height = button_height
    window.add_widget(btn_4)
    
    let btn_5 = nyagui.Button.new("5", fn() { on_digit("5") })
    btn_5.x = 10 + button_width + gap
    btn_5.y = button_y
    btn_5.width = button_width
    btn_5.height = button_height
    window.add_widget(btn_5)
    
    let btn_6 = nyagui.Button.new("6", fn() { on_digit("6") })
    btn_6.x = 10 + 2 * (button_width + gap)
    btn_6.y = button_y
    btn_6.width = button_width
    btn_6.height = button_height
    window.add_widget(btn_6)
    
    let btn_mul = nyagui.Button.new("*", fn() { on_operator("*") })
    btn_mul.x = 10 + 3 * (button_width + gap)
    btn_mul.y = button_y
    btn_mul.width = button_width
    btn_mul.height = button_height
    window.add_widget(btn_mul)
    
    # Row 6: 1, 2, 3, -
    button_y = button_y + button_height + gap
    
    let btn_1 = nyagui.Button.new("1", fn() { on_digit("1") })
    btn_1.x = 10
    btn_1.y = button_y
    btn_1.width = button_width
    btn_1.height = button_height
    window.add_widget(btn_1)
    
    let btn_2 = nyagui.Button.new("2", fn() { on_digit("2") })
    btn_2.x = 10 + button_width + gap
    btn_2.y = button_y
    btn_2.width = button_width
    btn_2.height = button_height
    window.add_widget(btn_2)
    
    let btn_3 = nyagui.Button.new("3", fn() { on_digit("3") })
    btn_3.x = 10 + 2 * (button_width + gap)
    btn_3.y = button_y
    btn_3.width = button_width
    btn_3.height = button_height
    window.add_widget(btn_3)
    
    let btn_sub = nyagui.Button.new("-", fn() { on_operator("-") })
    btn_sub.x = 10 + 3 * (button_width + gap)
    btn_sub.y = button_y
    btn_sub.width = button_width
    btn_sub.height = button_height
    window.add_widget(btn_sub)
    
    # Row 7: 0, ., =, +
    button_y = button_y + button_height + gap
    
    let btn_0 = nyagui.Button.new("0", fn() { on_digit("0") })
    btn_0.x = 10
    btn_0.y = button_y
    btn_0.width = button_width
    btn_0.height = button_height
    window.add_widget(btn_0)
    
    let btn_decimal = nyagui.Button.new(".", on_decimal)
    btn_decimal.x = 10 + button_width + gap
    btn_decimal.y = button_y
    btn_decimal.width = button_width
    btn_decimal.height = button_height
    window.add_widget(btn_decimal)
    
    let btn_eq = nyagui.Button.new("=", on_equals)
    btn_eq.x = 10 + 2 * (button_width + gap)
    btn_eq.y = button_y
    btn_eq.width = button_width
    btn_eq.height = button_height
    window.add_widget(btn_eq)
    
    let btn_add = nyagui.Button.new("+", fn() { on_operator("+") })
    btn_add.x = 10 + 3 * (button_width + gap)
    btn_add.y = button_y
    btn_add.width = button_width
    btn_add.height = button_height
    window.add_widget(btn_add)
    
    # Row 8: %, ^, +/-
    button_y = button_y + button_height + gap
    
    let btn_pct = nyagui.Button.new("%", on_percentage)
    btn_pct.x = 10
    btn_pct.y = button_y
    btn_pct.width = button_width
    btn_pct.height = button_height
    window.add_widget(btn_pct)
    
    let btn_pow = nyagui.Button.new("^", fn() { on_operator("^") })
    btn_pow.x = 10 + button_width + gap
    btn_pow.y = button_y
    btn_pow.width = button_width
    btn_pow.height = button_height
    window.add_widget(btn_pow)
    
    let btn_neg = nyagui.Button.new("+/-", on_toggle_sign)
    btn_neg.x = 10 + 2 * (button_width + gap)
    btn_neg.y = button_y
    btn_neg.width = button_width
    btn_neg.height = button_height
    window.add_widget(btn_neg)
    
    # Show window
    window.show()
    
    return window
}

# Main entry point
fn main() {
    print("Starting Nyx GUI Calculator...")
    let calc_window = create_calculator()
    print("Calculator created successfully!")
    print("Use: calc_window.run() to start the application")
}

# Run the main function
main()
