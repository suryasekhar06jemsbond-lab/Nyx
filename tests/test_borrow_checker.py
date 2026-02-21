"""
Tests for the Nyx Borrow Checker module.
Tests SafeSubsetDefinition, PerformanceModel, BorrowChecker, 
EnhancedBorrowChecker, LifetimeInference, and StaticVerifier.
"""

import unittest
from src.borrow_checker import (
    # Safe subset
    SafeSubsetCategory,
    SafeSubsetRule,
    SafeSubsetDefinition,
    # Performance model
    CostMetric,
    AbstractionAnalysis,
    PerformanceModel,
    # Types
    Mutability,
    Type,
    ReferenceType,
    OwnedType,
    Lifetime,
    Region,
    Constraint,
    # Core classes
    BorrowChecker,
    EnhancedBorrowChecker,
    LifetimeInference,
    AliasAnalysis,
    SoundnessProof,
    UBDetector,
    ZeroCostVerifier,
    # Diagnostics
    DiagnosticMessage,
    FixSuggestion,
    StaticVerifier,
)


class TestSafeSubsetDefinition(unittest.TestCase):
    """Tests for SafeSubsetDefinition - UB-free safe subset rules."""

    def test_safe_subset_initialization(self):
        """Test that safe subset rules are properly initialized."""
        rules = SafeSubsetDefinition.RULES
        self.assertGreater(len(rules), 0)
        
    def test_safe_subset_categories(self):
        """Test all safe subset categories are defined."""
        categories = [
            SafeSubsetCategory.MEMORY_SAFE,
            SafeSubsetCategory.ALIASING_SAFE,
            SafeSubsetCategory.LIFETIME_SAFE,
            SafeSubsetCategory.TYPE_SAFE,
            SafeSubsetCategory.THREAD_SAFE,
        ]
        for cat in categories:
            rules = SafeSubsetDefinition.get_rules_by_category(cat)
            self.assertIsInstance(rules, list)
            
    def test_compiler_enforced_rules(self):
        """Test getting compiler-enforced rules."""
        rules = SafeSubsetDefinition.get_compiler_enforced_rules()
        self.assertGreater(len(rules), 0)
        
    def test_runtime_required_rules(self):
        """Test getting rules that may require runtime checks."""
        rules = SafeSubsetDefinition.get_runtime_required_rules()
        self.assertIsInstance(rules, list)
        
    def test_verify_program_safe(self):
        """Test program safety verification."""
        # Test with valid context
        valid_context = {
            'null_checks': True,
            'bounds_checked': True,
            'bounds_proven': True,
            'no_mutable_alias': True,
            'exclusive_mut': True,
            'no_uaf': True,
            'no_dangling': True,
            'lifetime_valid': True,
            'initialized': True,
            'no_double_free': True,
            'valid_cast': True,
            'no_race': True,
        }
        is_safe, failed = SafeSubsetDefinition.verify_program_safe(valid_context)
        self.assertTrue(is_safe)
        self.assertEqual(len(failed), 0)
        
        # Test with invalid context
        invalid_context = {
            'null_checks': False,
            'bounds_checked': True,
        }
        is_safe, failed = SafeSubsetDefinition.verify_program_safe(invalid_context)
        self.assertFalse(is_safe)
        
    def test_safety_report(self):
        """Test generating safety report."""
        report = SafeSubsetDefinition.get_safety_report()
        self.assertIn('total_rules', report)
        self.assertIn('compiler_enforced', report)
        self.assertIn('by_category', report)


class TestPerformanceModel(unittest.TestCase):
    """Tests for PerformanceModel - Zero-cost abstraction verification."""

    def test_zero_cost_abstractions_defined(self):
        """Test that zero-cost abstractions are defined."""
        pm = PerformanceModel()
        self.assertGreater(len(pm.ZERO_COST_ABSTRACTIONS), 0)
        
    def test_analyze_abstraction_iterator(self):
        """Test analyzing iterator abstraction."""
        pm = PerformanceModel()
        analysis = pm.analyze_abstraction("iterator", "collections", 10, 5)
        self.assertIsInstance(analysis, AbstractionAnalysis)
        self.assertTrue(analysis.compile_time_verified)
        
    def test_analyze_abstraction_unknown(self):
        """Test analyzing unknown abstraction."""
        pm = PerformanceModel()
        analysis = pm.analyze_abstraction("unknown_abs", "custom", 10, 5)
        self.assertIsInstance(analysis, AbstractionAnalysis)
        self.assertFalse(analysis.compile_time_verified)
        
    def test_verify_zero_cost(self):
        """Test verifying zero-cost property."""
        pm = PerformanceModel()
        pm.analyze_abstraction("iterator", "collections", 10, 5)
        is_zero_cost, proof = pm.verify_zero_cost("iterator")
        self.assertIsInstance(is_zero_cost, bool)
        self.assertIsInstance(proof, str)
        
    def test_get_total_overhead(self):
        """Test calculating total overhead."""
        pm = PerformanceModel()
        pm.analyze_abstraction("iterator", "collections", 10, 5)
        pm.analyze_abstraction("option", "types", 10, 5)
        overhead = pm.get_total_overhead()
        self.assertIsInstance(overhead, CostMetric)
        
    def test_generate_performance_report(self):
        """Test generating performance report."""
        pm = PerformanceModel()
        pm.analyze_abstraction("iterator", "collections", 10, 5)
        report = pm.generate_performance_report()
        self.assertIn('total_abstractions', report)
        self.assertIn('zero_cost_count', report)


class TestBorrowChecker(unittest.TestCase):
    """Tests for basic BorrowChecker."""

    def setUp(self):
        self.checker = BorrowChecker()
        
    def test_check_borrow_immutable(self):
        """Test immutable borrow."""
        result = self.checker.check_borrow("x", mutable=False, line=1)
        self.assertTrue(result)
        
    def test_check_borrow_mutable(self):
        """Test mutable borrow."""
        result = self.checker.check_borrow("x", mutable=True, line=1)
        self.assertTrue(result)
        
    def test_check_borrow_after_mutable_fails(self):
        """Test that immutable borrow after mutable fails."""
        self.checker.check_borrow("x", mutable=True, line=1)
        result = self.checker.check_borrow("x", mutable=False, line=2)
        self.assertFalse(result)
        
    def test_check_borrow_moved_variable_fails(self):
        """Test that borrow of moved variable fails."""
        self.checker.moved_variables.add("x")
        result = self.checker.check_borrow("x", mutable=False, line=1)
        self.assertFalse(result)
        
    def test_check_assign(self):
        """Test assignment checking."""
        result = self.checker.check_assign("y", "x", line=1)
        self.assertTrue(result)
        
    def test_check_move(self):
        """Test move checking."""
        result = self.checker.check_move("x", line=1)
        self.assertTrue(result)
        
    def test_check_move_while_borrowed_fails(self):
        """Test that move while borrowed fails."""
        self.checker.check_borrow("x", mutable=False, line=1)
        result = self.checker.check_move("x", line=2)
        self.assertFalse(result)
        
    def test_end_borrow(self):
        """Test ending a borrow."""
        self.checker.check_borrow("x", mutable=False, line=1)
        self.checker.end_borrow("x", line=2)
        # Should not have errors now
        result = self.checker.check_borrow("x", mutable=True, line=3)
        self.assertTrue(result)
        
    def test_verify_no_errors(self):
        """Test verification with no errors."""
        result, errors = self.checker.verify()
        self.assertTrue(result)
        self.assertEqual(len(errors), 0)


class TestEnhancedBorrowChecker(unittest.TestCase):
    """Tests for EnhancedBorrowChecker with diagnostics."""

    def setUp(self):
        self.checker = EnhancedBorrowChecker()
        
    def test_check_borrow_with_diagnostics_mutable_conflict(self):
        """Test borrow diagnostics for mutable borrow conflict."""
        # First borrow - should succeed
        result = self.checker.check_borrow_with_diagnostics("x", True, 1)
        self.assertTrue(result)
        
        # Second mutable borrow - should fail with diagnostic
        result = self.checker.check_borrow_with_diagnostics("x", True, 2)
        self.assertFalse(result)
        self.assertTrue(self.checker.verifier.has_errors())
        
    def test_check_move_with_diagnostics(self):
        """Test move diagnostics."""
        result = self.checker.check_move_with_diagnostics("x", 1)
        self.assertTrue(result)
        
    def test_check_lifetime_with_diagnostics(self):
        """Test lifetime diagnostics."""
        result = self.checker.check_lifetime_with_diagnostics("'a", "'b", 1)
        self.assertFalse(result)
        
    def test_check_bounds_with_diagnostics(self):
        """Test bounds checking diagnostics."""
        # Valid bounds
        result = self.checker.check_bounds_with_diagnostics(2, 5, 1)
        self.assertTrue(result)
        
        # Out of bounds
        result = self.checker.check_bounds_with_diagnostics(10, 5, 1)
        self.assertFalse(result)
        
        # Negative index
        result = self.checker.check_bounds_with_diagnostics(-1, 5, 1)
        self.assertFalse(result)
        
    def test_verify_with_report(self):
        """Test verification with full diagnostic report."""
        valid, report = self.checker.verify_with_report()
        self.assertIsInstance(valid, bool)
        self.assertIsInstance(report, str)


class TestLifetimeInference(unittest.TestCase):
    """Tests for LifetimeInference."""

    def setUp(self):
        self.inference = LifetimeInference()
        
    def test_create_lifetime(self):
        """Test creating lifetime variable."""
        lv = self.inference.create_lifetime("'a")
        self.assertIsNotNone(lv)
        self.assertEqual(lv.name, "'a")
        
    def test_add_constraint(self):
        """Test adding lifetime constraint."""
        self.inference.create_lifetime("'a")
        self.inference.create_lifetime("'b")
        self.inference.add_constraint("'a", "'b")
        
    def test_solve(self):
        """Test solving lifetime constraints."""
        self.inference.create_lifetime("'a")
        self.inference.create_lifetime("'b")
        self.inference.add_constraint("'a", "'b")
        self.inference.add_constraint("'b", "'a")
        result = self.inference.solve()
        self.assertIsInstance(result, dict)


class TestStaticVerifier(unittest.TestCase):
    """Tests for StaticVerifier with comprehensive diagnostics."""

    def setUp(self):
        self.verifier = StaticVerifier()
        
    def test_add_error(self):
        """Test adding error diagnostic."""
        diag = self.verifier.add_error("E001", "Test error", "test.nyx:1:1")
        self.assertEqual(diag.severity, "error")
        self.assertEqual(diag.code, "E001")
        
    def test_add_warning(self):
        """Test adding warning diagnostic."""
        diag = self.verifier.add_warning("W001", "Test warning", "test.nyx:1:1")
        self.assertEqual(diag.severity, "warning")
        
    def test_add_info(self):
        """Test adding info diagnostic."""
        diag = self.verifier.add_info("I001", "Test info", "test.nyx:1:1")
        self.assertEqual(diag.severity, "info")
        
    def test_add_hint(self):
        """Test adding hint diagnostic."""
        diag = self.verifier.add_hint("H001", "Test hint", "test.nyx:1:1")
        self.assertEqual(diag.severity, "hint")
        
    def test_get_suggestion(self):
        """Test getting fix suggestion."""
        suggestion = self.verifier.get_suggestion("E001")
        self.assertIsInstance(suggestion, FixSuggestion)
        
    def test_generate_report(self):
        """Test generating diagnostic report."""
        self.verifier.add_error("E001", "Test error", "test.nyx:1:1")
        self.verifier.add_warning("W001", "Test warning", "test.nyx:2:1")
        report = self.verifier.generate_report()
        self.assertIsInstance(report, str)
        self.assertIn("Errors:", report)
        
    def test_has_errors(self):
        """Test checking for errors."""
        self.assertFalse(self.verifier.has_errors())
        self.verifier.add_error("E001", "Test error", "test.nyx:1:1")
        self.assertTrue(self.verifier.has_errors())
        
    def test_get_exit_code(self):
        """Test exit code generation."""
        self.assertEqual(self.verifier.get_exit_code(), 0)
        self.verifier.add_error("E001", "Test error", "test.nyx:1:1")
        self.assertEqual(self.verifier.get_exit_code(), 1)


class TestAliasAnalysis(unittest.TestCase):
    """Tests for AliasAnalysis."""

    def setUp(self):
        self.analysis = AliasAnalysis()
        
    def test_borrow_ref(self):
        """Test creating borrow reference."""
        self.analysis.borrow_ref("ptr1", "x", Mutability.IMMUTABLE)
        self.assertIn("ptr1", self.analysis.points_to)
        
    def test_assign(self):
        """Test assignment."""
        self.analysis.borrow_ref("ptr1", "x", Mutability.IMMUTABLE)
        self.analysis.assign("ptr2", "ptr1")
        self.assertIn("ptr2", self.analysis.points_to)
        
    def test_may_alias(self):
        """Test alias checking."""
        self.analysis.borrow_ref("ptr1", "x", Mutability.IMMUTABLE)
        self.analysis.borrow_ref("ptr2", "x", Mutability.IMMUTABLE)
        self.assertTrue(self.analysis.may_alias("ptr1", "ptr2"))


class TestUBDetector(unittest.TestCase):
    """Tests for UBDetector."""

    def setUp(self):
        self.detector = UBDetector()
        
    def test_check_null_deref_valid(self):
        """Test null deref check with valid value."""
        result = self.detector.check_null_deref("hello", 1)
        self.assertTrue(result)
        
    def test_check_null_deref_invalid(self):
        """Test null deref check with None."""
        result = self.detector.check_null_deref(None, 1)
        self.assertFalse(result)
        violations = self.detector.get_report()
        self.assertEqual(len(violations), 1)
        self.assertEqual(violations[0]["type"], "null_pointer_deref")


class TestSoundnessProof(unittest.TestCase):
    """Tests for SoundnessProof."""

    def test_prove_no_use_after_free(self):
        """Test proof of no use-after-free."""
        checker = BorrowChecker()
        # No active borrows
        result = SoundnessProof.prove_no_use_after_free(checker)
        self.assertTrue(result)


if __name__ == '__main__':
    unittest.main()
