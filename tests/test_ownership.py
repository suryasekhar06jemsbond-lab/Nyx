"""
Tests for the Nyx Ownership module.
Tests RAII, Thread Safety, Ownership, Soundness Proofs, and NyxSMode.
"""

import unittest
import threading
import time
from src.ownership import (
    # Core ownership
    OwnershipContext,
    Owner,
    Borrow,
    BorrowKind,
    Lifetime,
    RefType,
    NyxSMode,
    # RAII
    RAIIResource,
    RAIIScope,
    RAIIManager,
    # Thread Safety
    ThreadSafety,
    ThreadSafetyChecker,
    SendableKind,
    SyncKind,
    # Formal Proofs
    FormalSoundnessProofs,
    TypeEnv,
    TypedExpr,
    # Lifetime Inference
    LifetimeInference,
    # Zero-Cost Verification
    ZeroCostAbstraction,
    ZeroCostVerifier,
)


class TestRAIIResource(unittest.TestCase):
    """Tests for RAII Resource management."""

    def test_raii_resource_creation(self):
        """Test creating RAII resource."""
        resource = RAIIResource(
            resource_id=1,
            name="test_resource",
            acquired_at=10,
            is_acquired=True
        )
        self.assertEqual(resource.name, "test_resource")
        self.assertTrue(resource.is_acquired)
        
    def test_raii_resource_release(self):
        """Test releasing RAII resource."""
        released = []
        def destructor(name):
            released.append(name)
            
        resource = RAIIResource(
            resource_id=1,
            name="test_resource",
            acquired_at=10,
            destructor_fn=destructor,
            is_acquired=True
        )
        resource.release()
        self.assertFalse(resource.is_acquired)
        self.assertEqual(len(released), 1)
        self.assertEqual(released[0], "test_resource")
        
    def test_raii_resource_double_release(self):
        """Test that double release is safe."""
        resource = RAIIResource(
            resource_id=1,
            name="test_resource",
            acquired_at=10,
            is_acquired=True
        )
        resource.release()
        resource.release()  # Should not raise
        self.assertFalse(resource.is_acquired)


class TestRAIIScope(unittest.TestCase):
    """Tests for RAII Scope."""

    def test_raii_scope_context_manager(self):
        """Test RAII scope as context manager."""
        released = []
        
        def destructor(name):
            released.append(name)
            
        resource = RAIIResource(
            resource_id=1,
            name="test",
            acquired_at=10,
            destructor_fn=destructor
        )
        
        with RAIIScope(resource) as r:
            self.assertEqual(r.name, "test")
            self.assertTrue(r.is_acquired)
            
        # After exiting scope, resource should be released
        self.assertFalse(resource.is_acquired)
        self.assertEqual(len(released), 1)


class TestRAIIManager(unittest.TestCase):
    """Tests for RAII Manager."""

    def setUp(self):
        self.manager = RAIIManager()
        
    def test_acquire_resource(self):
        """Test acquiring resource."""
        resource = self.manager.acquire("test_resource")
        self.assertEqual(resource.name, "test_resource")
        self.assertTrue(resource.is_acquired)
        
    def test_release_resource(self):
        """Test releasing specific resource."""
        resource = self.manager.acquire("test_resource")
        self.manager.release(resource.resource_id)
        self.assertFalse(resource.is_acquired)
        
    def test_release_all(self):
        """Test releasing all resources."""
        self.manager.acquire("resource1")
        self.manager.acquire("resource2")
        self.manager.release_all()
        self.assertEqual(self.manager.get_active_count(), 0)
        
    def test_active_count(self):
        """Test getting active resource count."""
        self.manager.acquire("resource1")
        self.manager.acquire("resource2")
        self.assertEqual(self.manager.get_active_count(), 2)


class TestThreadSafety(unittest.TestCase):
    """Tests for Thread Safety system."""

    def test_thread_safety_creation(self):
        """Test creating thread safety object."""
        safety = ThreadSafety(
            is_send=True,
            is_sync=True,
            sendable_kind=SendableKind.ATOMIC,
            sync_kind=SyncKind.ATOMIC
        )
        self.assertTrue(safety.can_send())
        self.assertTrue(safety.can_sync())
        
    def test_thread_safety_not_sendable(self):
        """Test non-sendable type."""
        safety = ThreadSafety(is_send=False, is_sync=False)
        self.assertFalse(safety.can_send())
        self.assertFalse(safety.can_sync())


class TestThreadSafetyChecker(unittest.TestCase):
    """Tests for Thread Safety Checker."""

    def setUp(self):
        self.checker = ThreadSafetyChecker()
        
    def test_primitive_types_are_thread_safe(self):
        """Test that primitive types are thread-safe."""
        self.assertTrue(self.checker.check_send('i32'))
        self.assertTrue(self.checker.check_sync('i32'))
        self.assertTrue(self.checker.check_send('f64'))
        self.assertTrue(self.checker.check_sync('f64'))
        self.assertTrue(self.checker.check_send('bool'))
        self.assertTrue(self.checker.check_sync('bool'))
        
    def test_register_type(self):
        """Test registering custom type."""
        safety = ThreadSafety(
            is_send=True,
            is_sync=False,
            sendable_kind=SendableKind.OWNED,
        )
        self.checker.register_type("CustomType", safety)
        self.assertTrue(self.checker.check_send("CustomType"))
        
    def test_verify_no_data_race_no_race(self):
        """Test verifying no data race when properly synchronized."""
        accesses = [
            {'thread': 1, 'var': 'x', 'mutates': True, 'protected': True},
            {'thread': 2, 'var': 'x', 'mutates': True, 'protected': True},
        ]
        errors = self.checker.verify_no_data_race(accesses)
        self.assertEqual(len(errors), 0)
        
    def test_verify_no_data_race_detects_race(self):
        """Test detecting data race."""
        accesses = [
            {'thread': 1, 'var': 'x', 'mutates': True, 'protected': False},
            {'thread': 2, 'var': 'x', 'mutates': True, 'protected': False},
        ]
        errors = self.checker.verify_no_data_race(accesses)
        self.assertEqual(len(errors), 1)


class TestOwnershipContext(unittest.TestCase):
    """Tests for Ownership Context."""

    def setUp(self):
        self.ctx = OwnershipContext()
        
    def test_create_owner(self):
        """Test creating an owner."""
        owner_id = self.ctx.create_owner(42, "answer", 1)
        self.assertIsNotNone(owner_id)
        self.assertIn(owner_id, self.ctx.owners)
        
    def test_borrow_immutable(self):
        """Test creating immutable borrow."""
        owner_id = self.ctx.create_owner(42, "answer", 1)
        borrow_id = self.ctx.borrow_ref(owner_id, BorrowKind.IMMUTABLE, "'a", 2)
        self.assertIsNotNone(borrow_id)
        
    def test_borrow_mutable_exclusive(self):
        """Test mutable borrow is exclusive."""
        owner_id = self.ctx.create_owner(42, "answer", 1)
        # Create mutable borrow
        self.ctx.borrow_ref(owner_id, BorrowKind.MUTABLE, "'a", 2)
        # Second mutable borrow should fail
        with self.assertRaises(RuntimeError):
            self.ctx.borrow_ref(owner_id, BorrowKind.MUTABLE, "'b", 3)
            
    def test_borrow_immutable_after_mutable_fails(self):
        """Test immutable borrow after mutable fails."""
        owner_id = self.ctx.create_owner(42, "answer", 1)
        self.ctx.borrow_ref(owner_id, BorrowKind.MUTABLE, "'a", 2)
        with self.assertRaises(RuntimeError):
            self.ctx.borrow_ref(owner_id, BorrowKind.IMMUTABLE, "'b", 3)
            
    def test_get_borrowed_value(self):
        """Test getting value through borrow."""
        owner_id = self.ctx.create_owner(42, "answer", 1)
        borrow_id = self.ctx.borrow_ref(owner_id, BorrowKind.IMMUTABLE, "'a", 2)
        value = self.ctx.get_borrowed_value(borrow_id)
        self.assertEqual(value, 42)
        
    def test_end_borrow(self):
        """Test ending a borrow."""
        owner_id = self.ctx.create_owner(42, "answer", 1)
        borrow_id = self.ctx.borrow_ref(owner_id, BorrowKind.IMMUTABLE, "'a", 2)
        self.ctx.end_borrow(borrow_id)
        # Should be able to create mutable borrow now
        new_borrow_id = self.ctx.borrow_ref(owner_id, BorrowKind.MUTABLE, "'b", 3)
        self.assertIsNotNone(new_borrow_id)
        
    def test_move_owner(self):
        """Test moving ownership."""
        owner_id = self.ctx.create_owner(42, "answer", 1)
        new_owner_id = self.ctx.move_owner(owner_id, "new_answer", 2)
        self.assertNotEqual(owner_id, new_owner_id)
        
    def test_validate_lifetimes(self):
        """Test lifetime validation."""
        owner_id = self.ctx.create_owner(42, "answer", 1)
        self.ctx.borrow_ref(owner_id, BorrowKind.IMMUTABLE, "'a", 2)
        errors = self.ctx.validate_lifetimes(3)
        self.assertEqual(len(errors), 0)
        
    def test_check_no_active_borrows(self):
        """Test checking for active borrows."""
        owner_id = self.ctx.create_owner(42, "answer", 1)
        self.assertTrue(self.ctx.check_no_active_borrows(owner_id))
        self.ctx.borrow_ref(owner_id, BorrowKind.IMMUTABLE, "'a", 2)
        self.assertFalse(self.ctx.check_no_active_borrows(owner_id))


class TestFormalSoundnessProofs(unittest.TestCase):
    """Tests for Formal Soundness Proofs."""

    def setUp(self):
        self.proofs = FormalSoundnessProofs()
        
    def test_prove_progress_value(self):
        """Test progress proof for value."""
        env = TypeEnv()
        proof = self.proofs.prove_progress(42, "i32", env)
        self.assertTrue(proof['holds'])
        self.assertEqual(proof['theorem'], 'Progress')
        
    def test_prove_progress_expression(self):
        """Test progress proof for reducible expression."""
        env = TypeEnv()
        proof = self.proofs.prove_progress([1, "+", 2], "i32", env)
        self.assertTrue(proof['holds'])
        
    def test_prove_preservation(self):
        """Test preservation theorem."""
        env = TypeEnv()
        proof = self.proofs.prove_preservation(42, 42, "i32", env)
        self.assertTrue(proof['holds'])
        self.assertEqual(proof['theorem'], 'Preservation')
        
    def test_prove_soundness(self):
        """Test complete soundness proof."""
        env = TypeEnv()
        proof = self.proofs.prove_soundness(42, "i32", env)
        self.assertTrue(proof['sound'])
        self.assertEqual(proof['theorem'], 'Soundness')
        
    def test_get_proofs(self):
        """Test getting accumulated proofs."""
        env = TypeEnv()
        self.proofs.prove_progress(42, "i32", env)
        self.proofs.prove_preservation(42, 42, "i32", env)
        proofs = self.proofs.get_proofs()
        self.assertEqual(len(proofs), 2)


class TestTypeEnv(unittest.TestCase):
    """Tests for Type Environment."""

    def test_extend(self):
        """Test extending environment."""
        env = TypeEnv()
        new_env = env.extend("x", "i32")
        self.assertEqual(new_env.lookup("x"), "i32")
        # Original env unchanged
        self.assertIsNone(env.lookup("x"))
        
    def test_lookup(self):
        """Test looking up type."""
        env = TypeEnv()
        env.bindings["x"] = "i32"
        self.assertEqual(env.lookup("x"), "i32")
        self.assertIsNone(env.lookup("y"))


class TestLifetime(unittest.TestCase):
    """Tests for Lifetime."""

    def test_lifetime_valid(self):
        """Test lifetime validity."""
        lifetime = Lifetime("'a", 1, 10)
        self.assertTrue(lifetime.is_valid_at(5))
        self.assertFalse(lifetime.is_valid_at(15))
        
    def test_lifetime_outlives(self):
        """Test lifetime outlives relationship."""
        outer = Lifetime("'outer", 1, 20)
        inner = Lifetime("'inner", 5, 10)
        self.assertTrue(outer.outlives(inner))
        self.assertFalse(inner.outlives(outer))


class TestLifetimeInferenceOwnership(unittest.TestCase):
    """Tests for Lifetime Inference in ownership module."""

    def setUp(self):
        self.inference = LifetimeInference()
        
    def test_infer_lifetimes(self):
        """Test inferring lifetimes."""
        # Create mock borrows and owners
        class MockOwner:
            def __init__(self, id):
                self.object_id = id
                
        class MockBorrow:
            def __init__(self, owner_id, lifetime_name, line):
                self.owner_id = owner_id
                self.lifetime = Lifetime(lifetime_name, line)
                
        owners = {1: MockOwner(1)}
        borrows = [MockBorrow(1, "'a", 1)]
        
        result = self.inference.infer(borrows, owners)
        self.assertIsInstance(result, dict)


class TestZeroCostVerifier(unittest.TestCase):
    """Tests for Zero-Cost Verifier."""

    def setUp(self):
        self.verifier = ZeroCostVerifier()
        
    def test_verify_known_abstraction(self):
        """Test verifying known abstraction."""
        result = self.verifier.verify("Option")
        self.assertIsInstance(result, ZeroCostAbstraction)
        self.assertTrue(result.is_zero_cost)
        
    def test_verify_unknown_abstraction(self):
        """Test verifying unknown abstraction."""
        result = self.verifier.verify("UnknownAbstraction")
        self.assertIsInstance(result, ZeroCostAbstraction)
        self.assertFalse(result.is_zero_cost)
        
    def test_get_all_verified(self):
        """Test getting all verified abstractions."""
        self.verifier.verify("Option")
        self.verifier.verify("Result")
        verified = self.verifier.get_all_verified()
        self.assertEqual(len(verified), 2)


class TestNyxSMode(unittest.TestCase):
    """Tests for Nyx-S Systems Programming Mode."""

    def setUp(self):
        self.nyxs = NyxSMode()
        
    def test_borrow_immutable(self):
        """Test immutable borrow in NyxS mode."""
        owner_id = self.nyxs.ownership.create_owner(42, "x", 1)
        borrow_id = self.nyxs.borrow_immutable(owner_id, "'a", 2)
        self.assertIsNotNone(borrow_id)
        
    def test_borrow_mutable(self):
        """Test mutable borrow in NyxS mode."""
        owner_id = self.nyxs.ownership.create_owner(42, "x", 1)
        borrow_id = self.nyxs.borrow_mutable(owner_id, "'a", 2)
        self.assertIsNotNone(borrow_id)
        
    def test_move_value(self):
        """Test moving value in NyxS mode."""
        owner_id = self.nyxs.ownership.create_owner(42, "x", 1)
        new_owner_id = self.nyxs.move_value(owner_id, "y", 2)
        self.assertIsNotNone(new_owner_id)
        
    def test_acquire_resource(self):
        """Test acquiring RAII resource."""
        resource = self.nyxs.acquire_resource("test", None, 1)
        self.assertIsInstance(resource, RAIIResource)
        
    def test_check_thread_safety(self):
        """Test thread safety checking."""
        is_send, is_sync = self.nyxs.check_thread_safety("i32")
        self.assertTrue(is_send)
        self.assertTrue(is_sync)
        
    def test_prove_soundness(self):
        """Test soundness proof."""
        proof = self.nyxs.prove_soundness(42, "i32", TypeEnv())
        self.assertTrue(proof['sound'])
        
    def test_verify_zero_cost(self):
        """Test zero-cost verification."""
        result = self.nyxs.verify_zero_cost("Option")
        self.assertIsInstance(result, ZeroCostAbstraction)
        
    def test_validate(self):
        """Test validation."""
        errors = self.nyxs.validate(5)
        self.assertIsInstance(errors, list)


class TestRefType(unittest.TestCase):
    """Tests for Reference Type."""

    def test_ref_type_immutable(self):
        """Test immutable reference type."""
        ref = RefType(BorrowKind.IMMUTABLE, "i32")
        self.assertEqual(str(ref), "& i32")
        
    def test_ref_type_mutable(self):
        """Test mutable reference type."""
        ref = RefType(BorrowKind.MUTABLE, "i32")
        self.assertEqual(str(ref), "&mut i32")


if __name__ == '__main__':
    unittest.main()
