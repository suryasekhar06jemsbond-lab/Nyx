# Nyx Hello World - Production-Grade Syntax
# Demonstrates clean, expressive syntax with minimal LOC

# Simple hello world
print("Hello, Nyx!")

# Function with type inference
fn greet(name) = "Hello, " + name + "!"

# Call function
print(greet("World"))

# Pattern matching
fn describe(value) = match value {
    case 0 => "zero"
    case n if n > 0 => "positive"
    case n => "negative"
    case s if type(s) == "string" => "string: " + s
    case _ => "other"
}

print(describe(42))
print(describe(-5))
print(describe("Nyx"))

# List comprehension
let numbers = [1, 2, 3, 4, 5]
let squares = [x * x for x in numbers if x % 2 == 1]
print("Odd squares:", squares)

# Pipeline operator
let result = numbers
    |> filter(|x| x > 2)
    |> map(|x| x * 2)
    |> reduce(0, |acc, x| acc + x)
print("Pipeline result:", result)

# Async example
async fn fetch_data(url) = {
    await sleep(1000)  # Simulate network delay
    "Data from " + url
}

# Spawn async task
let handle = spawn || {
    let data = await fetch_data("https://api.example.com")
    print(data)
}

# Class definition
class User {
    name: string
    age: int
    
    fn new(name, age) = Self { name, age }
    
    fn greet(self) = "Hi, I'm " + self.name + " and I'm " + self.age + " years old"
}

let user = User::new("Alice", 25)
print(user.greet())

# Error handling with Result type
fn divide(a, b) = match b {
    case 0 => Err("Division by zero")
    case _ => Ok(a / b)
}

let result = try! divide(10, 2)
print("10 / 2 =", result)

# Generic function
fn identity[T](x) = x

print(identity("generic"))
print(identity(42))

# Macro example (simplified)
macro assert_eq!(a, b) = {
    if a != b {
        throw f"Assertion failed: {a} != {b}"
    }
}

assert_eq!(2 + 2, 4)
print("All tests passed!")
