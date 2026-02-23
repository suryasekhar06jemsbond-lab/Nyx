# Basic Nyx syntax/runtime smoke checks
let x = 10;
let y = x + 5;
let arr = [1, 2, 3];
let sum = 0;
for (i in [1, 2, 3, 4, 5]) {
  sum = sum + i;
}
fn add(a, b) {
  return a + b;
}
print("basic");
print(y);
print(arr[0]);
print(sum);
print(add(3, 4));