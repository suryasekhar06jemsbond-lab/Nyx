import threading
import unittest

from src.ownership import OwnershipTracker
from src.borrow_checker import BorrowChecker, validate_borrow_trace


class TestOwnershipBorrow(unittest.TestCase):
    def test_ownership_hooks_and_move(self):
        seen = []
        tracker = OwnershipTracker()
        tracker.declare("resource", "alice")
        tracker.register_before_move_hook(lambda r, old, new: seen.append((r, old, new)))
        tracker.move("resource", "bob")
        self.assertEqual(seen, [("resource", "alice", "bob")])
        snap = tracker.snapshot()
        self.assertEqual(snap["resource"]["owner"], "bob")
        self.assertTrue(snap["resource"]["moved"])

    def test_borrow_checker_rules(self):
        bc = BorrowChecker()
        bc.borrow_immutable("x")
        with self.assertRaises(RuntimeError):
            bc.borrow_mutable("x")
        bc.release_immutable("x")
        bc.borrow_mutable("x")
        with self.assertRaises(RuntimeError):
            bc.borrow_immutable("x")

    def test_thread_safety_smoke(self):
        bc = BorrowChecker()

        def worker(i):
            name = f"n{i%4}"
            bc.borrow_immutable(name)
            bc.release_immutable(name)

        threads = [threading.Thread(target=worker, args=(i,)) for i in range(50)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        self.assertTrue(len(bc.snapshot()) >= 1)

    def test_trace_validator(self):
        valid = [
            {"op": "borrow_immut", "name": "x"},
            {"op": "release_immut", "name": "x"},
            {"op": "borrow_mut", "name": "x"},
            {"op": "release_mut", "name": "x"},
        ]
        self.assertTrue(validate_borrow_trace(valid))


if __name__ == "__main__":
    unittest.main()
