import inspect
import unittest

from src import ast_nodes
from src.lexer import Lexer
from src.parser import Parser
from src.interpreter import Interpreter, Environment
from src.debugger import ErrorDetector
from src.ownership import OwnershipTracker
from src.borrow_checker import BorrowChecker
from src.token_types import TokenRegistry, TokenType, create_registry
import src.lexer as lexer_mod
import src.parser as parser_mod
import src.interpreter as interpreter_mod
import src.debugger as debugger_mod
import src.ownership as ownership_mod
import src.borrow_checker as borrow_checker_mod
import src.token_types as token_types_mod


class TestContracts(unittest.TestCase):
    def test_token_registry_contract(self):
        reg = TokenRegistry.create_default()
        self.assertIn("let", reg.keywords)
        self.assertIn("==", [op for op, _ in reg.multi_char_tokens])
        custom = create_registry({"keywords": {"module": "IDENT"}})
        self.assertEqual(custom.lookup_ident("module"), TokenType.IDENT)

    def test_lexer_contract(self):
        sig = inspect.signature(Lexer.__init__)
        self.assertIn("registry", sig.parameters)
        self.assertIn("options", sig.parameters)
        lx = Lexer("let x = 1;")
        toks = list(lx.tokenize())
        self.assertGreaterEqual(len(toks), 2)

    def test_parser_contract(self):
        parser = Parser(Lexer("let x = 1;"))
        self.assertTrue(hasattr(parser, "register_prefix"))
        self.assertTrue(hasattr(parser, "register_infix"))
        self.assertTrue(hasattr(parser, "register_statement"))
        self.assertTrue(hasattr(parser, "register_error_hook"))
        program = parser.parse()
        self.assertEqual(len(program.statements), 1)

    def test_interpreter_contract(self):
        interp = Interpreter()
        self.assertTrue(hasattr(interp, "register_builtin"))
        self.assertTrue(hasattr(interp, "register_module"))
        self.assertTrue(hasattr(interp, "register_import_resolver"))
        self.assertTrue(hasattr(interp, "resolve_module"))
        self.assertTrue(hasattr(interp, "eval_node"))
        env = Environment()
        value = interp.eval_node(Parser(Lexer("1 + 2;")).parse_program(), env)
        self.assertEqual(value, 3)

    def test_debugger_contract(self):
        det = ErrorDetector()
        issues = det.detect("(")
        self.assertGreaterEqual(len(issues), 1)
        self.assertTrue(det.has_errors())

    def test_ownership_borrow_contract(self):
        own = OwnershipTracker()
        own.declare("res", "a")
        own.move("res", "b")
        snap = own.snapshot()
        self.assertTrue(snap["res"]["moved"])

        bc = BorrowChecker()
        bc.borrow_immutable("x")
        bc.release_immutable("x")
        bc.borrow_mutable("x")
        bc.release_mutable("x")
        self.assertIn("x", bc.snapshot())

    def test_ast_registry_contract(self):
        node = ast_nodes.create_node("FutureNode", enabled=True)
        d = ast_nodes.node_to_dict(node)
        self.assertEqual(d["_type"], "DynamicNode")

    def test_api_version_contract(self):
        mods = [
            lexer_mod,
            parser_mod,
            interpreter_mod,
            debugger_mod,
            ownership_mod,
            borrow_checker_mod,
            token_types_mod,
            ast_nodes,
        ]
        for mod in mods:
            self.assertRegex(getattr(mod, "API_VERSION", ""), r"^\d+\.\d+\.\d+$")


if __name__ == "__main__":
    unittest.main()
