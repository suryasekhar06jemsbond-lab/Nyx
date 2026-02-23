import unittest

from src.lexer import Lexer
from src.parser import Parser


GRAMMAR_CASES = [
    "let x = 1; let y = 2; return x + y;",
    "if (true) { let a = 1; } else { let a = 2; }",
    "fn add(x, y) { x + y; }",
    "let arr = [1, 2, 3]; arr[1];",
    "let m = {\"a\": 1, \"b\": 2};",
    "while (x < 10) { x = x + 1; }",
    "for (item in arr) { item; }",
    "import \"std/math\";",
    "from \"std/math\" import pi;",
    "class MyType: Base { pass; }",
]


class TestParserGrammarCoverage(unittest.TestCase):
    def test_matrix_parses_without_crash(self):
        for source in GRAMMAR_CASES:
            parser = Parser(Lexer(source))
            program = parser.parse_program()
            self.assertTrue(hasattr(program, "statements"))
            self.assertLess(len(parser.errors), 5, msg=f"Too many errors for case: {source}\n{parser.errors}")


if __name__ == "__main__":
    unittest.main()
