from __future__ import annotations

API_VERSION = "1.0.0"

from dataclasses import dataclass
from enum import Enum, auto
import re
from typing import Callable, Dict, List, Optional


class Severity(Enum):
    CRITICAL = auto()
    HIGH = auto()
    MEDIUM = auto()
    LOW = auto()


@dataclass
class DebugIssue:
    code: str
    message: str
    severity: Severity = Severity.MEDIUM
    line: Optional[int] = None
    column: Optional[int] = None


class ErrorDetector:
    def __init__(self):
        self.errors: List[DebugIssue] = []
        self.syntax_rules: List[Callable[[str, "ErrorDetector"], None]] = [
            self._rule_balanced_parentheses,
            self._rule_balanced_braces,
            self._rule_balanced_brackets,
            self._rule_unterminated_string,
            self._rule_assignment_in_condition,
        ]
        self.type_rules: List[Callable[[str, "ErrorDetector"], None]] = [
            self._rule_null_order_comparison,
        ]

    def add(self, code: str, message: str, severity: Severity = Severity.MEDIUM, line: int | None = None, column: int | None = None) -> None:
        self.errors.append(DebugIssue(code=code, message=message, severity=severity, line=line, column=column))

    def clear(self) -> None:
        self.errors.clear()

    def register_syntax_rule(self, rule: Callable[[str, "ErrorDetector"], None]) -> None:
        self.syntax_rules.append(rule)

    def register_type_rule(self, rule: Callable[[str, "ErrorDetector"], None]) -> None:
        self.type_rules.append(rule)

    def _rule_balanced_parentheses(self, code: str, detector: "ErrorDetector") -> None:
        open_paren = code.count("(")
        close_paren = code.count(")")
        if open_paren != close_paren:
            detector.add("E100", "Unbalanced parentheses", Severity.HIGH)

    def _rule_balanced_braces(self, code: str, detector: "ErrorDetector") -> None:
        if code.count("{") != code.count("}"):
            detector.add("E101", "Unbalanced braces", Severity.HIGH)

    def _rule_balanced_brackets(self, code: str, detector: "ErrorDetector") -> None:
        if code.count("[") != code.count("]"):
            detector.add("E102", "Unbalanced brackets", Severity.HIGH)

    def _rule_unterminated_string(self, code: str, detector: "ErrorDetector") -> None:
        single = len(re.findall(r"(?<!\\)'", code))
        double = len(re.findall(r'(?<!\\)"', code))
        if single % 2 != 0 or double % 2 != 0:
            detector.add("E103", "Unterminated string literal", Severity.HIGH)

    def _rule_assignment_in_condition(self, code: str, detector: "ErrorDetector") -> None:
        if re.search(r"\b(if|while)\s*\([^)]*=[^=][^)]*\)", code):
            detector.add("W210", "Suspicious assignment inside condition", Severity.MEDIUM)

    def _rule_null_order_comparison(self, code: str, detector: "ErrorDetector") -> None:
        if re.search(r"\bnull\s*[<>]=?\s*[\w(]", code) or re.search(r"[\w)]+\s*[<>]=?\s*null\b", code):
            detector.add("T300", "Ordering comparison against null is likely invalid", Severity.MEDIUM)

    def detect_syntax(self, code: str) -> None:
        for rule in self.syntax_rules:
            rule(code, self)

    def check_types(self, code: str) -> None:
        for rule in self.type_rules:
            rule(code, self)

    def report_errors(self) -> List[DebugIssue]:
        return list(self.errors)

    def summary(self) -> Dict[str, int]:
        out = {
            "critical": 0,
            "high": 0,
            "medium": 0,
            "low": 0,
            "total": len(self.errors),
        }
        for issue in self.errors:
            if issue.severity == Severity.CRITICAL:
                out["critical"] += 1
            elif issue.severity == Severity.HIGH:
                out["high"] += 1
            elif issue.severity == Severity.MEDIUM:
                out["medium"] += 1
            else:
                out["low"] += 1
        return out

    def has_errors(self, min_severity: Severity = Severity.LOW) -> bool:
        order = {
            Severity.LOW: 0,
            Severity.MEDIUM: 1,
            Severity.HIGH: 2,
            Severity.CRITICAL: 3,
        }
        threshold = order[min_severity]
        return any(order[e.severity] >= threshold for e in self.errors)

    # Backward-compatible API name.
    def detect(self, code: str) -> List[DebugIssue]:
        self.detect_syntax(code)
        self.check_types(code)
        return self.report_errors()


class IssueReporter:
    def __init__(self):
        self.issues: List[str] = []

    def report_issue(self, description: str) -> None:
        self.issues.append(description)

    def export(self) -> List[str]:
        return list(self.issues)
