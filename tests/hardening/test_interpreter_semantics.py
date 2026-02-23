import unittest

from src.interpreter import Environment, Interpreter
from src.lexer import Lexer
from src.parser import Parser


def run(source: str):
    parser = Parser(Lexer(source))
    program = parser.parse_program()
    if parser.errors:
        raise AssertionError(parser.errors)
    return Interpreter().eval(program, Environment())


class TestInterpreterSemantics(unittest.TestCase):
    def test_arithmetic_precedence(self):
        self.assertEqual(run("1 + 2 * 3;"), 7)
        self.assertEqual(run("(1 + 2) * 3;"), 9)

    def test_if_else(self):
        self.assertEqual(run("if (true) { 10; } else { 20; }"), 10)
        self.assertEqual(run("if (false) { 10; } else { 20; }"), 20)

    def test_function_calls_and_closure(self):
        source = """
        let make = fn(x) { fn(y) { x + y; } };
        let add2 = make(2);
        add2(8);
        """
        self.assertEqual(run(source), 10)

    def test_arrays_and_hashes(self):
        self.assertEqual(run("[1,2,3][2];"), 3)
        self.assertEqual(run("{\"a\": 7}[\"a\"];"), 7)

    def test_for_in_accumulation(self):
        source = """
        let total = 0;
        for (v in [1,2,3,4]) { total = total + v; }
        total;
        """
        self.assertEqual(run(source), 10)


if __name__ == "__main__":
    unittest.main()
