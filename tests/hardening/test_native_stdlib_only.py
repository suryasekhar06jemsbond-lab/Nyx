import ast
import sys
import unittest
from pathlib import Path


TARGETS = [
    "src/token_types.py",
    "src/lexer.py",
    "src/parser.py",
    "src/interpreter.py",
    "src/debugger.py",
    "src/ownership.py",
    "src/borrow_checker.py",
    "src/ast_nodes.py",
]


class TestNativeStdlibOnly(unittest.TestCase):
    def test_core_modules_use_only_stdlib_or_internal_imports(self):
        root = Path(__file__).resolve().parents[2]
        stdlib = set(getattr(sys, "stdlib_module_names", set()))
        allow = {"src", "__future__"}
        for rel in TARGETS:
            p = root / rel
            tree = ast.parse(p.read_text(encoding="utf-8"), filename=str(p))
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        top = alias.name.split(".")[0]
                        self.assertTrue(
                            top in stdlib or top in allow,
                            msg=f"{rel}: third-party/non-native import '{alias.name}'",
                        )
                elif isinstance(node, ast.ImportFrom):
                    if node.module is None:
                        continue
                    top = node.module.split(".")[0]
                    self.assertTrue(
                        top in stdlib or top in allow,
                        msg=f"{rel}: third-party/non-native import '{node.module}'",
                    )


if __name__ == "__main__":
    unittest.main()
