
let d = {};
for (i in range(500)) {
    let key = "key_" + i;
    d[key] = i * 2;
}

let total = 0;
let vals = values(d);
for (v in vals) {
    total = total + v;
}
print(total);
