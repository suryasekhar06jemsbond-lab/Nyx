
let arr = [];
for (i in range(1000)) {
    arr = arr + [i * 2];
}

let total = 0;
for (item in arr) {
    total = total + item;
}
print(total);
