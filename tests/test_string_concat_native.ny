
let user = "user_" + 5;
print(user);

let count = 42;
let message = "Count is: " + count;
print(message);

let name = "Nyx";
let version = 1;
let full = name + " v" + version + ".0";
print(full);

let items = "";
for (i in range(5)) {
    let item = "item_" + i;
    if (i > 0) {
        items = items + ", ";
    }
    items = items + item;
}
print(items);

let num = 999;
let text = "Number: " + str(num);
print(text);

let a = 10;
let b = 20;
let result = "Sum of " + a + " and " + b + " is " + (a + b);
print(result);

print("All native string concatenation tests passed!");



