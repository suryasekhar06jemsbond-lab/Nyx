# Test file to verify optional semicolons work in Nyx

# With semicolons
let x = 5;
let y = 10;
let sum = x + y;

# Without semicolons  
let a = 20
let b = 30
let product = a * b

# Mixed style
let c = 100;
let d = 200
let result = c + d;

# Function definitions
fn add(x, y) {
    return x + y;
}

fn multiply(x, y) {
    return x * y
}

# Function calls
let val1 = add(1, 2);
let val2 = multiply(3, 4)

# Print statements
print("With semicolon:");
print(sum);

print("Without semicolon:")
print(product)

# Return values
fn test() {
    let temp = 42;
    return temp
}

print("Test result:", test())
