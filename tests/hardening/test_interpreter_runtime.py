import unittest

from src.interpreter import Interpreter, Environment, NULL
from src.lexer import Lexer
from src.parser import Parser


def run(src: str):
    parser = Parser(Lexer(src))
    program = parser.parse_program()
    if parser.errors:
        raise AssertionError(parser.errors)
    return Interpreter().eval(program, Environment())


class TestInterpreterRuntime(unittest.TestCase):
    def test_math_and_logic(self):
        self.assertEqual(run("1 + 2 * 3;"), 7)
        self.assertEqual(run("(1 + 2) * 3;"), 9)
        self.assertTrue(run("1 < 2;") is True)

    def test_loops_and_control_flow(self):
        src = """
        let x = 0;
        while (x < 5) {
            x = x + 1;
            break;
        }
        x;
        """
        self.assertEqual(run(src), 1)

    def test_for_in(self):
        src = """
        let total = 0;
        for (v in [1,2,3]) { total = total + v; }
        total;
        """
        self.assertEqual(run(src), 6)

    def test_import_registry(self):
        interp = Interpreter()
        interp.register_module("std/math", {"pi": 3.14, "one": 1})
        env = Environment()
        program = Parser(Lexer('from "std/math" import pi; pi;')).parse_program()
        value = interp.eval(program, env)
        self.assertEqual(value, 3.14)

    def test_step_limit(self):
        interp = Interpreter()
        interp.max_steps = 50
        with self.assertRaises(RuntimeError):
            interp.eval(Parser(Lexer("while (true) { }" )).parse_program(), Environment())

    def test_unknown_node_soft_mode(self):
        class Unknown:
            pass
        interp = Interpreter()
        self.assertIs(interp.eval(Unknown(), Environment()), NULL)


if __name__ == "__main__":
    unittest.main()
