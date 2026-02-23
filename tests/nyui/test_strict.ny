# Auto-normalized smoke test for current Nyx runtime
use nymath;

fn smoke(name) {
    let values = [1, 2, 3, 4];
    let total = 0;
    for (v in values) {
        total = total + v;
    }
    print(name);
    print(total);
    return total;
}

let out = smoke("test_strict.ny");
if (out != 10) {
    throw "smoke failed";
}