import time
import unittest

from src.lexer import Lexer
from src.parser import Parser
from src.interpreter import Interpreter, Environment


class TestPerfSmoke(unittest.TestCase):
    def test_lexer_parser_interpreter_perf_smoke(self):
        program = "\n".join(
            ["let x = 0;"]
            + ["x = x + 1;" for _ in range(2000)]
            + ["x;"]
        )
        t0 = time.perf_counter()
        parser = Parser(Lexer(program))
        ast = parser.parse_program()
        self.assertLess(len(parser.errors), 5)
        value = Interpreter().eval(ast, Environment())
        elapsed = time.perf_counter() - t0
        self.assertEqual(value, 2000)
        self.assertLess(elapsed, 5.0)


if __name__ == "__main__":
    unittest.main()
