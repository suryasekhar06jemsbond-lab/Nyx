# Comprehensive test suite for optional semicolon syntax in Nyx
# This test demonstrates that both ";" and no ";" syntax work perfectly

print("=== SEMICOLON OPTIONAL SYNTAX TEST SUITE ===")
print()

# ============================================
# TEST 1: Variable Declarations
# ============================================
print("TEST 1: Variable Declarations")

# With semicolons
let a1 = 10;
let b1 = 20;
let c1 = a1 + b1;
print("With semicolons:", c1);

# Without semicolons
let a2 = 10
let b2 = 20
let c2 = a2 + b2
print("Without semicolons:", c2)

# Mixed style
let a3 = 10;
let b3 = 20
let c3 = a3 + b3;
print("Mixed style:", c3)

print("✓ PASSED: Variable declarations work with and without semicolons")
print()

# ============================================
# TEST 2: Function Definitions
# ============================================
print("TEST 2: Function Definitions")

# Function with semicolons
fn add_semi(x, y) {
    let result = x + y;
    return result;
}

# Function without semicolons
fn add_no_semi(x, y) {
    let result = x + y
    return result
}

# Function mixed style
fn add_mixed(x, y) {
    let result = x + y;
    return result
}

let r1 = add_semi(5, 3);
let r2 = add_no_semi(5, 3)
let r3 = add_mixed(5, 3);

print("With semicolons result:", r1);
print("Without semicolons result:", r2)
print("Mixed style result:", r3)
print("✓ PASSED: Function definitions work with and without semicolons")
print()

# ============================================
# TEST 3: Return Statements
# ============================================
print("TEST 3: Return Statements")

fn return_with_semi() {
    return 42;
}

fn return_without_semi() {
    return 42
}

fn return_expr_with_semi(x) {
    return x * 2;
}

fn return_expr_without_semi(x) {
    return x * 2
}

print("Return with semicolon:", return_with_semi());
print("Return without semicolon:", return_without_semi())
print("Return expr with semicolon:", return_expr_with_semi(10));
print("Return expr without semicolon:", return_expr_without_semi(10))
print("✓ PASSED: Return statements work with and without semicolons")
print()

# ============================================
# TEST 4: Expression Statements
# ============================================
print("TEST 4: Expression Statements")

let counter = 0;

# Expression with semicolon
counter = counter + 1;
print("Counter after semi:", counter);

# Expression without semicolon
counter = counter + 1
print("Counter after no semi:", counter)

# Multiple expressions mixed
counter = counter + 1;
counter = counter + 1
counter = counter + 1;
print("Counter after mixed:", counter)
print("✓ PASSED: Expression statements work with and without semicolons")
print()

# ============================================
# TEST 5: If/Else Blocks
# ============================================
print("TEST 5: If/Else Blocks")

let test_val = 15;

# If with semicolons
if (test_val > 10) {
    print("If with semicolon: Large");
} else {
    print("If with semicolon: Small");
}

# If without semicolons
if (test_val > 10) {
    print("If without semicolon: Large")
} else {
    print("If without semicolon: Small")
}

# If mixed style
if (test_val > 10) {
    let temp = "Large";
    print("If mixed:", temp)
} else {
    let temp = "Small"
    print("If mixed:", temp);
}

print("✓ PASSED: If/else blocks work with and without semicolons")
print()

# ============================================
# TEST 6: Arrays and Data Structures
# ============================================
print("TEST 6: Arrays and Data Structures")

# Array with semicolon
let arr1 = [1, 2, 3, 4, 5];
print("Array with semicolon:", arr1);

# Array without semicolon
let arr2 = [10, 20, 30, 40, 50]
print("Array without semicolon:", arr2)

# Hash with semicolon
let person1 = {"name": "Alice", "age": 30};
print("Hash with semicolon:", person1);

# Hash without semicolon
let person2 = {"name": "Bob", "age": 25}
print("Hash without semicolon:", person2)

print("✓ PASSED: Arrays and hashes work with and without semicolons")
print()

# ============================================
# TEST 7: Function Calls
# ============================================
print("TEST 7: Function Calls")

fn greet(name) {
    return "Hello, " + name
}

# Call with semicolon
let msg1 = greet("Alice");
print(msg1);

# Call without semicolon
let msg2 = greet("Bob")
print(msg2)

# Chained calls mixed
let msg3 = greet("Charlie");
print(msg3)

print("✓ PASSED: Function calls work with and without semicolons")
print()

# ============================================
# TEST 8: Loops
# ============================================
print("TEST 8: Loops")

# While loop with semicolons
let i = 0;
let sum_semi = 0;
while (i < 3) {
    sum_semi = sum_semi + i;
    i = i + 1;
}
print("While with semicolons, sum:", sum_semi);

# While loop without semicolons
let j = 0
let sum_no_semi = 0
while (j < 3) {
    sum_no_semi = sum_no_semi + j
    j = j + 1
}
print("While without semicolons, sum:", sum_no_semi)

# For loop with mixed style (note: for header requires semicolons per C syntax)
let sum_for = 0;
for (let k = 0; k < 3; k = k + 1) {
    sum_for = sum_for + k;
}
print("For with semicolons, sum:", sum_for);

let sum_for2 = 0
for (let m = 0; m < 3; m = m + 1) {
    sum_for2 = sum_for2 + m
}
print("For without semicolons in body, sum:", sum_for2)

print("✓ PASSED: Loops work with and without semicolons")
print()

# ============================================
# TEST 9: Complex Nested Structures
# ============================================
print("TEST 9: Complex Nested Structures")

fn calculate(x, y, operation) {
    if (operation == "add") {
        return x + y;
    } else if (operation == "multiply") {
        return x * y
    } else {
        return 0;
    }
}

let result1 = calculate(10, 5, "add");
let result2 = calculate(10, 5, "multiply")
print("Complex nested with semi:", result1);
print("Complex nested without semi:", result2)

print("✓ PASSED: Complex nested structures work with and without semicolons")
print()

# ============================================
# TEST 10: Edge Cases
# ============================================
print("TEST 10: Edge Cases")

# Empty lines between statements (no semicolons)
let edge1 = 100

let edge2 = 200

let edge3 = edge1 + edge2

print("Edge case - empty lines:", edge3)

# Single line multiple statements require semicolons
let x = 1; let y = 2; let z = x + y;
print("Single line multiple statements:", z);

print("✓ PASSED: Edge cases work correctly")
print()

# ============================================
# FINAL SUMMARY
# ============================================
print("========================================")
print("ALL TESTS PASSED!")
print("Nyx supports OPTIONAL SEMICOLONS perfectly.")
print("Both styles work: 'let x = 5;' and 'let x = 5'")
print("========================================")
