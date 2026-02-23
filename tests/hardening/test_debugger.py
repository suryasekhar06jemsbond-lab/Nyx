import unittest

from src.debugger import ErrorDetector, IssueReporter, Severity


class TestDebugger(unittest.TestCase):
    def test_builtin_rule_detects_parentheses(self):
        det = ErrorDetector()
        issues = det.detect("((a)")
        self.assertGreaterEqual(len(issues), 1)
        self.assertTrue(det.has_errors(min_severity=Severity.LOW))

    def test_custom_rules(self):
        det = ErrorDetector()

        def syntax_rule(code, detector):
            if "@@" in code:
                detector.add("E777", "illegal marker", Severity.HIGH, 1, 1)

        det.register_syntax_rule(syntax_rule)
        det.detect("@@")
        self.assertTrue(any(i.code == "E777" for i in det.report_errors()))

    def test_reporter_export(self):
        rep = IssueReporter()
        rep.report_issue("bad thing")
        self.assertEqual(rep.export(), ["bad thing"])


if __name__ == "__main__":
    unittest.main()
