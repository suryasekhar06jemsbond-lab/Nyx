import random
import string
import unittest

from src.lexer import Lexer
from src.parser import Parser
from src.token_types import TokenType


class TestLexerParserFuzz(unittest.TestCase):
    def test_fuzz_lexer_never_raises(self):
        random.seed(1337)
        alphabet = string.ascii_letters + string.digits + string.punctuation + " \n\t"
        for _ in range(300):
            size = random.randint(0, 300)
            source = "".join(random.choice(alphabet) for _ in range(size))
            lexer = Lexer(source)
            tokens = list(lexer.tokens())
            self.assertGreaterEqual(len(tokens), 1)
            self.assertEqual(tokens[-1].type, TokenType.EOF)

    def test_fuzz_parser_never_raises(self):
        random.seed(2026)
        corpus = [
            "let x = 1;",
            "fn add(a,b){a+b;}",
            "if (x < 10) { let y = x; } else { let y = 0; }",
            "while (x < 5) { x = x + 1; }",
            "for (i in arr) { i; }",
            "[1,2,3][0];",
            "{\"k\": 1};",
        ]
        noise = string.ascii_letters + string.digits + string.punctuation + " \n\t"
        for _ in range(250):
            base = random.choice(corpus)
            suffix = "".join(random.choice(noise) for _ in range(random.randint(0, 40)))
            parser = Parser(Lexer(base + suffix))
            program = parser.parse_program()
            self.assertTrue(hasattr(program, "statements"))


if __name__ == "__main__":
    unittest.main()
