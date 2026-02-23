import unittest

from src.debugger import ErrorDetector


class TestDebuggerRuleset(unittest.TestCase):
    def test_balancing_rules(self):
        det = ErrorDetector()
        issues = det.detect("if (x > 1 { arr[0; ")
        codes = {i.code for i in issues}
        self.assertIn("E100", codes)
        self.assertIn("E101", codes)
        self.assertIn("E102", codes)

    def test_unterminated_string_rule(self):
        det = ErrorDetector()
        issues = det.detect('let x = "oops;')
        self.assertTrue(any(i.code == "E103" for i in issues))

    def test_suspicious_assignment_rule(self):
        det = ErrorDetector()
        issues = det.detect("if (x = 1) { x; }")
        self.assertTrue(any(i.code == "W210" for i in issues))

    def test_summary(self):
        det = ErrorDetector()
        det.detect("if (x = 1) {")
        summary = det.summary()
        self.assertGreater(summary["total"], 0)
        self.assertIn("high", summary)


if __name__ == "__main__":
    unittest.main()
