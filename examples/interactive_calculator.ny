# Interactive Calculator in Nyx (parser-compatible)
# - Supports +, -, *, /, %, //, **, and parentheses
# - Handles unary minus for negative numbers
# - Uses only arrays and strings (no object literals)
# - Avoids else-if and complex inline constructs

fn is_digit(ch) = {
    let s = str(ch);
    let digits = "0123456789";
    for (d in digits) {
        if (s == str(d)) { return true; }
    }
    return false;
}

fn is_space(ch) = {
    let s = str(ch);
    if (s == " ") { return true; }
    if (s == "\t") { return true; }
    return false;
}

fn is_op_char(ch) = {
    let s = str(ch);
    if (s == "+") { return true; }
    if (s == "-") { return true; }
    if (s == "*") { return true; }
    if (s == "/") { return true; }
    if (s == "%") { return true; }
    return false;
}

fn last_is_value(tokens) = {
    if (len(tokens) == 0) { return false; }
    let t = tokens[len(tokens) - 1];
    if (t == ")") { return true; }
    # Number token: first char is '-' or digit or '.'; we treat it as number if it has a digit
    let has_digit = false;
    for (c in t) {
        if (is_digit(c)) { has_digit = true; break; }
    }
    return has_digit;
}

# Tokenize input line to array of string tokens
fn tokenize(line) = {
    let chars = [];
    for (c in line) { push(chars, c); }

    let tokens = [];
    let i = 0;
    let n = len(chars);

    while (i < n) {
        let ch = chars[i];
        if (is_space(ch)) {
            i = i + 1;
            continue;
        }

        if (str(ch) == "(") {
            push(tokens, "(");
            i = i + 1;
            continue;
        }
        if (str(ch) == ")") {
            push(tokens, ")");
            i = i + 1;
            continue;
        }

        # Unary minus handling
        let has_sign = false;
        if (str(ch) == "-") {
            if (!last_is_value(tokens) && i + 1 < n) {
                let nxt = chars[i+1];
                if (is_digit(nxt) || str(nxt) == ".") {
                    has_sign = true;
                    i = i + 1;
                }
            }
        }

        # Number literal
        if (has_sign || is_digit(ch) || str(ch) == ".") {
            let lit = "";
            if (has_sign) { lit = lit + "-"; }
            let seen_dot = false;
            while (i < n) {
                let c = chars[i];
                if (is_digit(c)) {
                    lit = lit + str(c);
                    i = i + 1;
                } else {
                    if (str(c) == "." && !seen_dot) {
                        seen_dot = true;
                        lit = lit + ".";
                        i = i + 1;
                    } else {
                        break;
                    }
                }
            }
            push(tokens, lit);
            continue;
        }

        # Multi-char operators first
        if (str(ch) == "*" && i + 1 < n && str(chars[i+1]) == "*") {
            push(tokens, "**");
            i = i + 2;
            continue;
        }
        if (str(ch) == "/" && i + 1 < n && str(chars[i+1]) == "/") {
            push(tokens, "//");
            i = i + 2;
            continue;
        }

        # Single-char operators
        if (is_op_char(ch)) {
            push(tokens, str(ch));
            i = i + 1;
            continue;
        }

        # Unknown character: skip
        i = i + 1;
    }

    return tokens;
}

fn precedence(op) = {
    if (op == "+") { return 1; }
    if (op == "-") { return 1; }
    if (op == "*") { return 2; }
    if (op == "/") { return 2; }
    if (op == "%") { return 2; }
    if (op == "//") { return 2; }
    if (op == "**") { return 3; }
    return 0;
}

fn is_right_assoc(op) = (op == "**");

fn is_number_token(tok) = {
    # token is number if it has at least one digit and only digits/dot/leading '-'
    if (tok == "") { return false; }
    let j = 0;
    let m = len(tok);
    let has_digit = false;
    if (tok[0] == "-") { j = 1; }
    while (j < m) {
        let c = tok[j];
        if (is_digit(c)) { has_digit = true; }
        else {
            if (c == ".") {
                # allow only dot
            } else {
                return false;
            }
        }
        j = j + 1;
    }
    return has_digit;
}

# Shunting-yard: tokens[] -> rpn[] (all strings)
fn to_rpn(tokens) = {
    let output = [];
    let ops = [];

    for (t in tokens) {
        if (is_number_token(t)) {
            push(output, t);
        } else {
            if (t == "(") {
                push(ops, t);
            } else {
                if (t == ")") {
                    while (len(ops) > 0 && ops[len(ops)-1] != "(") {
                        push(output, ops[len(ops)-1]);
                        pop(ops);
                    }
                    if (len(ops) > 0 && ops[len(ops)-1] == "(") { pop(ops); }
                } else {
                    # operator
                    let p1 = precedence(t);
                    while (len(ops) > 0) {
                        let top = ops[len(ops) - 1];
                        if (top == "(") { break; }
                        let p2 = precedence(top);
                        if ((!is_right_assoc(t) && p1 <= p2) || (is_right_assoc(t) && p1 < p2)) {
                            push(output, top);
                            pop(ops);
                        } else {
                            break;
                        }
                    }
                    push(ops, t);
                }
            }
        }
    }

    while (len(ops) > 0) {
        push(output, ops[len(ops)-1]);
        pop(ops);
    }

    return output;
}

# Evaluate RPN array (strings) to a number (int or float)
fn eval_rpn(rpn) = {
    let st = [];
    for (t in rpn) {
        if (is_number_token(t)) {
            # choose float if '.' present
            let val = 0;
            let has_dot = false;
            for (c in t) { if (c == ".") { has_dot = true; break; } }
            if (has_dot) { val = float(t); } else { val = int(t); }
            push(st, val);
        } else {
            # operator: pop rhs then lhs
            let b = st[len(st)-1]; pop(st);
            let a = st[len(st)-1]; pop(st);
            if (t == "+") { push(st, a + b); }
            else {
                if (t == "-") { push(st, a - b); }
                else {
                    if (t == "*") { push(st, a * b); }
                    else {
                        if (t == "/") { push(st, a / b); }
                        else {
                            if (t == "%") { push(st, a % b); }
                            else {
                                if (t == "//") { push(st, int(a / b)); }
                                else {
                                    if (t == "**") { push(st, a ** b); }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if (len(st) == 0) { return 0; }
    return st[len(st)-1];
}

fn calculate(line) = {
    let tokens = tokenize(line);
    let rpn = to_rpn(tokens);
    return eval_rpn(rpn);
}

# REPL
fn main() = {
    print("Interactive Calculator (Nyx)\nType 'exit' or 'quit' to leave.\n");
    while (true) {
        let line = input("calc> ");
        if (line == null) { break; }
        if (line == "") { continue; }
        if (line == "exit" || line == "quit") { break; }
        try {
            let result = calculate(line);
            print(result);
        } except (e) {
            print("Error:", str(e));
        }
    }
    print("Bye.");
}

main();
