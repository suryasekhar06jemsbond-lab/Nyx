import inspect
import json
import unittest
from importlib import import_module
from pathlib import Path


SNAPSHOT = Path(__file__).resolve().parent / "contracts" / "public_api_v1.json"


class TestApiCompatibilitySnapshot(unittest.TestCase):
    def test_public_api_subset_is_stable(self):
        data = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
        for target, expected in data.items():
            module_name, cls_name = target.split(":")
            mod = import_module(module_name)
            cls = getattr(mod, cls_name)
            actual = {
                name
                for name, member in inspect.getmembers(cls)
                if callable(member) and not name.startswith("_")
            }
            for method in expected:
                self.assertIn(method, actual, msg=f"Missing public API: {target}.{method}")


if __name__ == "__main__":
    unittest.main()
