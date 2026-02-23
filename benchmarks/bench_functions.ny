
fn add(a, b) {
    return a + b;
}

let result = 0;
for (i in range(1000)) {
    result = add(result, i);
}
print(result);
