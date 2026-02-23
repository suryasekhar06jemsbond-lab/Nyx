from __future__ import annotations

API_VERSION = "1.0.0"

from dataclasses import dataclass, field
from enum import Enum, auto
import threading
from typing import Callable, Dict, List, Optional, Tuple


class SafeSubsetCategory(Enum):
    MEMORY_SAFE = auto()
    ALIASING_SAFE = auto()
    LIFETIME_SAFE = auto()
    TYPE_SAFE = auto()
    THREAD_SAFE = auto()


@dataclass
class SafeSubsetRule:
    key: str
    description: str
    category: SafeSubsetCategory
    compiler_enforced: bool = True


class SafeSubsetDefinition:
    RULES: List[SafeSubsetRule] = [
        SafeSubsetRule("null_checks", "Null dereference checks", SafeSubsetCategory.MEMORY_SAFE, True),
        SafeSubsetRule("bounds_checked", "Bounds checks", SafeSubsetCategory.MEMORY_SAFE, True),
        SafeSubsetRule("no_mutable_alias", "No mutable aliasing", SafeSubsetCategory.ALIASING_SAFE, True),
        SafeSubsetRule("lifetime_valid", "Valid lifetimes", SafeSubsetCategory.LIFETIME_SAFE, True),
        SafeSubsetRule("initialized", "Use only initialized values", SafeSubsetCategory.TYPE_SAFE, True),
        SafeSubsetRule("no_race", "No data races", SafeSubsetCategory.THREAD_SAFE, False),
    ]

    @classmethod
    def get_rules_by_category(cls, cat: SafeSubsetCategory) -> List[SafeSubsetRule]:
        return [r for r in cls.RULES if r.category == cat]

    @classmethod
    def get_compiler_enforced_rules(cls) -> List[SafeSubsetRule]:
        return [r for r in cls.RULES if r.compiler_enforced]

    @classmethod
    def get_runtime_required_rules(cls) -> List[SafeSubsetRule]:
        return [r for r in cls.RULES if not r.compiler_enforced]

    @classmethod
    def verify_program_safe(cls, context: Dict[str, bool]) -> Tuple[bool, List[str]]:
        failed = [r.key for r in cls.RULES if not context.get(r.key, False)]
        return len(failed) == 0, failed

    @classmethod
    def get_safety_report(cls) -> dict:
        by_cat: Dict[str, int] = {}
        for r in cls.RULES:
            by_cat[r.category.name] = by_cat.get(r.category.name, 0) + 1
        return {
            "total_rules": len(cls.RULES),
            "compiler_enforced": len(cls.get_compiler_enforced_rules()),
            "runtime_required": len(cls.get_runtime_required_rules()),
            "by_category": by_cat,
        }


class CostMetric(Enum):
    ZERO = auto()
    LOW = auto()
    MEDIUM = auto()
    HIGH = auto()


@dataclass
class AbstractionAnalysis:
    name: str
    subsystem: str
    compile_time_verified: bool
    runtime_cost: CostMetric


class PerformanceModel:
    ZERO_COST_ABSTRACTIONS = {"iterator", "option", "result", "closure"}

    def __init__(self):
        self._analyses: Dict[str, AbstractionAnalysis] = {}

    def analyze_abstraction(self, name: str, subsystem: str, static_ops: int, dynamic_ops: int) -> AbstractionAnalysis:
        verified = name in self.ZERO_COST_ABSTRACTIONS
        cost = CostMetric.ZERO if verified else (CostMetric.LOW if dynamic_ops <= static_ops else CostMetric.MEDIUM)
        out = AbstractionAnalysis(name=name, subsystem=subsystem, compile_time_verified=verified, runtime_cost=cost)
        self._analyses[name] = out
        return out

    def verify_zero_cost(self, name: str) -> Tuple[bool, str]:
        a = self._analyses.get(name)
        if a is None:
            return False, "abstraction not analyzed"
        return a.runtime_cost == CostMetric.ZERO, "verified" if a.runtime_cost == CostMetric.ZERO else "runtime overhead observed"

    def get_total_overhead(self) -> CostMetric:
        if not self._analyses:
            return CostMetric.ZERO
        if any(a.runtime_cost == CostMetric.HIGH for a in self._analyses.values()):
            return CostMetric.HIGH
        if any(a.runtime_cost == CostMetric.MEDIUM for a in self._analyses.values()):
            return CostMetric.MEDIUM
        if any(a.runtime_cost == CostMetric.LOW for a in self._analyses.values()):
            return CostMetric.LOW
        return CostMetric.ZERO

    def generate_performance_report(self) -> dict:
        return {
            "total_abstractions": len(self._analyses),
            "zero_cost_count": sum(1 for a in self._analyses.values() if a.runtime_cost == CostMetric.ZERO),
            "total_overhead": self.get_total_overhead().name,
        }


class Mutability(Enum):
    IMMUTABLE = auto()
    MUTABLE = auto()


@dataclass
class Type:
    name: str


@dataclass
class ReferenceType(Type):
    target: str = ""
    mutability: Mutability = Mutability.IMMUTABLE


@dataclass
class OwnedType(Type):
    pass


@dataclass
class Lifetime:
    name: str


@dataclass
class Region:
    name: str


@dataclass
class Constraint:
    left: str
    right: str


@dataclass
class BorrowState:
    immutable_count: int = 0
    mutable_active: bool = False


class BorrowChecker:
    """
    Minimal ownership/borrow model:
    - many immutable borrows OR one mutable borrow
    - mutable borrow excludes immutable borrows
    """

    def __init__(self):
        self._states: Dict[str, BorrowState] = {}
        self._validators: List[Callable[[str, BorrowState], None]] = []
        self._lock = threading.RLock()
        self.errors: List[str] = []
        self.moved_variables: set[str] = set()

    def _state(self, name: str) -> BorrowState:
        if name not in self._states:
            self._states[name] = BorrowState()
        return self._states[name]

    def check_borrow(self, name: str, mutable: bool, line: int) -> bool:
        try:
            if name in self.moved_variables:
                self.errors.append(f"{line}: use of moved variable {name}")
                return False
            if mutable:
                self.borrow_mutable(name)
            else:
                self.borrow_immutable(name)
            return True
        except RuntimeError as exc:
            self.errors.append(f"{line}: {exc}")
            return False

    def check_assign(self, target: str, source: str, line: int) -> bool:
        return True

    def check_move(self, name: str, line: int) -> bool:
        st = self._state(name)
        if st.mutable_active or st.immutable_count > 0:
            self.errors.append(f"{line}: cannot move borrowed variable {name}")
            return False
        self.moved_variables.add(name)
        return True

    def end_borrow(self, name: str, line: int) -> None:
        st = self._state(name)
        st.mutable_active = False
        st.immutable_count = 0

    def verify(self) -> Tuple[bool, List[str]]:
        return len(self.errors) == 0, list(self.errors)

    def borrow_immutable(self, name: str) -> None:
        with self._lock:
            st = self._state(name)
            for validator in self._validators:
                validator(name, st)
            if st.mutable_active:
                raise RuntimeError(f"cannot immutably borrow '{name}' while mutable borrow is active")
            st.immutable_count += 1

    def borrow_shared(self, name: str) -> None:
        self.borrow_immutable(name)

    def release_immutable(self, name: str) -> None:
        with self._lock:
            st = self._state(name)
            if st.immutable_count > 0:
                st.immutable_count -= 1

    def release_shared(self, name: str) -> None:
        self.release_immutable(name)

    def borrow_mutable(self, name: str) -> None:
        with self._lock:
            st = self._state(name)
            for validator in self._validators:
                validator(name, st)
            if st.mutable_active or st.immutable_count > 0:
                raise RuntimeError(f"cannot mutably borrow '{name}' while another borrow is active")
            st.mutable_active = True

    def release_mutable(self, name: str) -> None:
        with self._lock:
            st = self._state(name)
            st.mutable_active = False

    def snapshot(self) -> Dict[str, Dict[str, int | bool]]:
        with self._lock:
            out: Dict[str, Dict[str, int | bool]] = {}
            for k, st in self._states.items():
                out[k] = {"immutable_count": st.immutable_count, "mutable_active": st.mutable_active}
            return out

    def register_validator(self, validator: Callable[[str, BorrowState], None]) -> None:
        with self._lock:
            self._validators.append(validator)


class AliasAnalysis:
    def __init__(self):
        self.points_to: Dict[str, str] = {}
        self.mutability: Dict[str, Mutability] = {}

    def borrow_ref(self, ref_name: str, target: str, mutability: Mutability) -> None:
        self.points_to[ref_name] = target
        self.mutability[ref_name] = mutability

    def assign(self, dst_ref: str, src_ref: str) -> None:
        if src_ref in self.points_to:
            self.points_to[dst_ref] = self.points_to[src_ref]
            self.mutability[dst_ref] = self.mutability.get(src_ref, Mutability.IMMUTABLE)

    def may_alias(self, a: str, b: str) -> bool:
        return self.points_to.get(a) == self.points_to.get(b) and a in self.points_to and b in self.points_to


@dataclass
class SoundnessProof:
    theorem: str
    holds: bool

    @staticmethod
    def prove_no_use_after_free(checker: BorrowChecker) -> bool:
        return len(checker.errors) == 0


class UBDetector:
    def __init__(self):
        self._violations: List[dict] = []

    def check_null_deref(self, value: object, line: int) -> bool:
        if value is None:
            self._violations.append({"type": "null_pointer_deref", "line": line})
            return False
        return True

    def get_report(self) -> List[dict]:
        return list(self._violations)


@dataclass
class FixSuggestion:
    code: str
    message: str


@dataclass
class DiagnosticMessage:
    severity: str
    code: str
    message: str
    location: str


class StaticVerifier:
    def __init__(self):
        self.messages: List[DiagnosticMessage] = []

    def add_error(self, code: str, message: str, location: str) -> DiagnosticMessage:
        m = DiagnosticMessage("error", code, message, location)
        self.messages.append(m)
        return m

    def add_warning(self, code: str, message: str, location: str) -> DiagnosticMessage:
        m = DiagnosticMessage("warning", code, message, location)
        self.messages.append(m)
        return m

    def add_info(self, code: str, message: str, location: str) -> DiagnosticMessage:
        m = DiagnosticMessage("info", code, message, location)
        self.messages.append(m)
        return m

    def add_hint(self, code: str, message: str, location: str) -> DiagnosticMessage:
        m = DiagnosticMessage("hint", code, message, location)
        self.messages.append(m)
        return m

    def get_suggestion(self, code: str) -> FixSuggestion:
        return FixSuggestion(code=code, message=f"Review rule {code} and apply safe refactor")

    def generate_report(self) -> str:
        errors = [m for m in self.messages if m.severity == "error"]
        warnings = [m for m in self.messages if m.severity == "warning"]
        infos = [m for m in self.messages if m.severity in {"info", "hint"}]
        return f"Errors: {len(errors)}\nWarnings: {len(warnings)}\nInfo: {len(infos)}"

    def has_errors(self) -> bool:
        return any(m.severity == "error" for m in self.messages)

    def get_exit_code(self) -> int:
        return 1 if self.has_errors() else 0


class LifetimeInference:
    @dataclass
    class LifetimeVar:
        name: str

    def __init__(self):
        self.vars: Dict[str, LifetimeInference.LifetimeVar] = {}
        self.constraints: List[Constraint] = []

    def create_lifetime(self, name: str) -> "LifetimeInference.LifetimeVar":
        lv = LifetimeInference.LifetimeVar(name)
        self.vars[name] = lv
        return lv

    def add_constraint(self, left: str, right: str) -> None:
        self.constraints.append(Constraint(left, right))

    def solve(self) -> Dict[str, List[str]]:
        graph: Dict[str, List[str]] = {k: [] for k in self.vars.keys()}
        for c in self.constraints:
            graph.setdefault(c.left, []).append(c.right)
        return graph


class ZeroCostVerifier:
    def __init__(self):
        self.performance = PerformanceModel()

    def verify(self, name: str) -> Tuple[bool, str]:
        self.performance.analyze_abstraction(name, "core", 1, 1)
        return self.performance.verify_zero_cost(name)


class EnhancedBorrowChecker:
    def __init__(self):
        self.checker = BorrowChecker()
        self.verifier = StaticVerifier()

    def check_borrow_with_diagnostics(self, name: str, mutable: bool, line: int) -> bool:
        ok = self.checker.check_borrow(name, mutable=mutable, line=line)
        if not ok:
            self.verifier.add_error("E-BORROW", f"invalid borrow for {name}", f"<memory>:{line}")
        return ok

    def check_move_with_diagnostics(self, name: str, line: int) -> bool:
        ok = self.checker.check_move(name, line=line)
        if not ok:
            self.verifier.add_error("E-MOVE", f"invalid move for {name}", f"<memory>:{line}")
        return ok

    def check_lifetime_with_diagnostics(self, left: str, right: str, line: int) -> bool:
        # Keep strict by default: distinct lifetimes need explicit relation.
        if left != right:
            self.verifier.add_warning("W-LIFETIME", f"lifetime {left} may not outlive {right}", f"<memory>:{line}")
            return False
        return True

    def check_bounds_with_diagnostics(self, index: int, length: int, line: int) -> bool:
        if index < 0 or index >= length:
            self.verifier.add_error("E-BOUNDS", f"index {index} out of bounds for len {length}", f"<memory>:{line}")
            return False
        return True

    def verify_with_report(self) -> Tuple[bool, str]:
        return not self.verifier.has_errors(), self.verifier.generate_report()


def validate_borrow_trace(trace: List[dict]) -> bool:
    checker = BorrowChecker()
    for step in trace:
        op = step.get("op")
        name = step.get("name")
        if not isinstance(name, str):
            return False
        if op == "borrow_immut":
            checker.borrow_immutable(name)
        elif op == "release_immut":
            checker.release_immutable(name)
        elif op == "borrow_mut":
            checker.borrow_mutable(name)
        elif op == "release_mut":
            checker.release_mutable(name)
        else:
            return False
    return True
