# NYCORE - Nyx Foundation Engine Simple Test
# Testing basic Nyx language features

# Test 1: Variables and printing
let x = 10;
print("Test 1: Variable x = ");
print(x);

# Test 2: Arithmetic
let y = x + 5;
print("Test 2: y = x + 5 = ");
print(y);

# Test 3: Boolean
let flag = true;
print("Test 3: flag = ");
print(flag);

# Test 4: String
let name = "Nyx";
print("Test 4: name = ");
print(name);

# Test 5: Array
let arr = [1, 2, 3];
print("Test 5: arr len = ");
print(arr.len());

# Test 6: Map
let data = {"key": "value"};
print("Test 6: data[key] = ");
print(data["key"]);

# Test 7: Loop
let sum = 0;
for i in [1, 2, 3, 4, 5] {
  sum = sum + i;
};
print("Test 7: sum of 1-5 = ");
print(sum);

# Test 8: Function
fn add(a, b) {
  return a + b;
};
let result = add(3, 4);
print("Test 8: add(3,4) = ");
print(result);

print("All basic tests passed!");
