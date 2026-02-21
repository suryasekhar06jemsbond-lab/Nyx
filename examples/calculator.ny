# Nyx Calculator - Advanced Mathematical Operations
# Demonstrates type safety, pattern matching, and functional programming

# Basic arithmetic with type inference
fn add(a, b) = a + b
fn subtract(a, b) = a - b
fn multiply(a, b) = a * b
fn divide(a, b) = {
    if b == 0 {
        Err("Division by zero")
    } else {
        Ok(a / b)
    }
}

# Advanced mathematical functions
fn factorial(n) = match n {
    case 0 => 1
    case 1 => 1
    case n => n * factorial(n - 1)
}

fn fibonacci(n) = match n {
    case 0 => 0
    case 1 => 1
    case n => fibonacci(n - 1) + fibonacci(n - 2)
}

fn gcd(a, b) = match b {
    case 0 => a
    case _ => gcd(b, a % b)
}

fn lcm(a, b) = (a * b) / gcd(a, b)

# Power function with exponentiation by squaring
fn power(base, exp) = match exp {
    case 0 => 1
    case 1 => base
    case n if n % 2 == 0 => {
        let half = power(base, n / 2)
        half * half
    }
    case n => base * power(base, n - 1)
}

# Square root using Newton's method
fn sqrt(n, epsilon = 0.0001) = {
    if n < 0 {
        Err("Cannot take square root of negative number")
    } else if n == 0 {
        Ok(0)
    } else {
        let guess = n / 2
        sqrt_iter(n, guess, epsilon)
    }
}

fn sqrt_iter(n, guess, epsilon) = {
    let new_guess = (guess + n / guess) / 2
    if abs(new_guess - guess) < epsilon {
        Ok(new_guess)
    } else {
        sqrt_iter(n, new_guess, epsilon)
    }
}

# Trigonometric functions (simplified)
fn sin(x) = {
    # Taylor series approximation
    let n = 10
    let result = sum([(-1)^k * x^(2*k + 1) / factorial(2*k + 1) for k in 0..=n])
    result
}

fn cos(x) = {
    # Taylor series approximation
    let n = 10
    let result = sum([(-1)^k * x^(2*k) / factorial(2*k) for k in 0..=n])
    result
}

# Statistics functions
fn mean(numbers) = sum(numbers) / len(numbers)

fn median(numbers) = {
    let sorted = sort(numbers)
    let n = len(sorted)
    if n % 2 == 0 {
        (sorted[n/2 - 1] + sorted[n/2]) / 2
    } else {
        sorted[n/2]
    }
}

fn mode(numbers) = {
    let counts = {num: count(numbers, num) for num in unique(numbers)}
    let max_count = max(counts.values())
    let modes = [num for num, count in counts if count == max_count]
    if len(modes) == 1 {
        modes[0]
    } else {
        modes
    }
}

fn variance(numbers) = {
    let m = mean(numbers)
    let squared_diffs = [(x - m)^2 for x in numbers]
    mean(squared_diffs)
}

fn std_deviation(numbers) = sqrt(variance(numbers))

# Matrix operations
struct Matrix {
    data: [[float]]
    rows: int
    cols: int
}

impl Matrix {
    fn new(data) = {
        let rows = len(data)
        let cols = len(data[0])
        Self { data, rows, cols }
    }
    
    fn add(self, other) = {
        if self.rows != other.rows or self.cols != other.cols {
            Err("Matrix dimensions must match")
        } else {
            let new_data = [
                [self.data[i][j] + other.data[i][j] for j in 0..self.cols-1]
                for i in 0..self.rows-1
            ]
            Ok(Matrix::new(new_data))
        }
    }
    
    fn multiply(self, other) = {
        if self.cols != other.rows {
            Err("Matrix dimensions incompatible")
        } else {
            let new_data = [
                [
                    sum([self.data[i][k] * other.data[k][j] for k in 0..self.cols-1])
                    for j in 0..other.cols-1
                ]
                for i in 0..self.rows-1
            ]
            Ok(Matrix::new(new_data))
        }
    }
    
    fn transpose(self) = {
        let new_data = [
            [self.data[j][i] for j in 0..self.rows-1]
            for i in 0..self.cols-1
        ]
        Matrix::new(new_data)
    }
}

# Complex numbers
struct Complex {
    real: float
    imag: float
}

impl Complex {
    fn new(real, imag) = Self { real, imag }
    
    fn add(self, other) = Complex::new(self.real + other.real, self.imag + other.imag)
    fn subtract(self, other) = Complex::new(self.real - other.real, self.imag - other.imag)
    fn multiply(self, other) = Complex::new(
        self.real * other.real - self.imag * other.imag,
        self.real * other.imag + self.imag * other.real
    )
    
    fn magnitude(self) = sqrt(self.real^2 + self.imag^2)
    fn conjugate(self) = Complex::new(self.real, -self.imag)
}

# Calculator class with history
class Calculator {
    history: [float]
    
    fn new() = Self { history: [] }
    
    fn calculate(self, operation, a, b) = match operation {
        case "+" => self.add_to_history(a + b)
        case "-" => self.add_to_history(a - b)
        case "*" => self.add_to_history(a * b)
        case "/" => {
            let result = try! divide(a, b)
            self.add_to_history(result)
        }
        case "^" => self.add_to_history(power(a, b))
        case _ => Err("Unknown operation")
    }
    
    fn add_to_history(self, result) = {
        self.history.push(result)
        Ok(result)
    }
    
    fn get_history(self) = self.history
    fn clear_history(self) = { self.history = [] }
}

# Usage examples
let calc = Calculator::new()

# Basic operations
print("2 + 3 =", calc.calculate("+", 2, 3))
print("10 - 4 =", calc.calculate("-", 10, 4))
print("6 * 7 =", calc.calculate("*", 6, 7))
print("15 / 3 =", calc.calculate("/", 15, 3))
print("2^8 =", calc.calculate("^", 2, 8))

# Advanced functions
print("Factorial 5 =", factorial(5))
print("Fibonacci 10 =", fibonacci(10))
print("GCD(48, 18) =", gcd(48, 18))
print("LCM(48, 18) =", lcm(48, 18))
print("Square root of 25 =", try! sqrt(25))

# Statistics
let data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
print("Mean of data =", mean(data))
print("Median of data =", median(data))
print("Mode of data =", mode(data))
print("Standard deviation =", try! std_deviation(data))

# Matrix operations
let matrix_a = Matrix::new([[1, 2], [3, 4]])
let matrix_b = Matrix::new([[5, 6], [7, 8]])
let sum = try! matrix_a.add(matrix_b)
let product = try! matrix_a.multiply(matrix_b)

print("Matrix sum =", sum)
print("Matrix product =", product)

# Complex numbers
let c1 = Complex::new(3, 4)
let c2 = Complex::new(1, 2)
let c_sum = c1.add(c2)
let c_product = c1.multiply(c2)

print("Complex sum =", c_sum)
print("Complex product =", c_product)
print("Magnitude =", c_sum.magnitude())

# History
print("Calculation history:", calc.get_history())
