"""Quota, budget, and idempotency on the local SQLite ledger."""

from __future__ import annotations

import tempfile
import threading
import unittest
from pathlib import Path

from hosted.ledger import (
    BudgetExceeded,
    CallFinished,
    IdempotencyConflict,
    QuotaExceeded,
    SponsoredPaused,
)
from hosted.money import micros_to_usd, usd_to_micros
from tests.hosted_support import open_ledger, spec


class MoneyTests(unittest.TestCase):
    def test_half_up_micros(self):
        self.assertEqual(usd_to_micros("0.02"), 20_000)
        self.assertEqual(usd_to_micros("0.15"), 150_000)
        self.assertEqual(usd_to_micros("400"), 400_000_000)
        self.assertEqual(usd_to_micros("1.2345675"), 1_234_568)
        self.assertEqual(usd_to_micros("1.2345674"), 1_234_567)
        self.assertEqual(micros_to_usd(20_000), "0.020000")


class LedgerBudgetTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.ledger = open_ledger(self.root)
        self.addCleanup(self.ledger.close)
        self.addCleanup(self.tmp.cleanup)

    def _reserve(self, key: str, amount: int, user: str = "user-alice", job: str = "job-1"):
        return self.ledger.reserve_call(
            idempotency_key=key,
            user_id=user,
            job_id=job,
            kind="image",
            model="gemini",
            reserved_micros=amount,
            daily_budget_micros=1_000_000,
            monthly_budget_micros=1_000_000,
        )

    def test_parallel_reserves_cannot_overshoot(self):
        barrier = threading.Barrier(8)
        results = []
        errors = []

        def attempt(index: int):
            try:
                barrier.wait(timeout=5)
                row = self._reserve(f"call-{index}", 400_000, job=f"job-{index}")
                results.append(row["idempotency_key"])
            except BudgetExceeded as exc:
                errors.append(exc)
            except Exception as exc:
                errors.append(exc)

        threads = [threading.Thread(target=attempt, args=(i,)) for i in range(8)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
        self.assertEqual(len(results), 2, errors)
        self.assertEqual(len(errors), 6)
        self.assertTrue(all(isinstance(item, BudgetExceeded) for item in errors))
        self.assertEqual(self.ledger.spend()["daily"], 800_000)

    def test_same_call_key_reserves_once(self):
        barrier = threading.Barrier(4)
        rows = []

        def attempt():
            barrier.wait(timeout=5)
            rows.append(self._reserve("same-key", 400_000))

        threads = [threading.Thread(target=attempt) for _ in range(4)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
        self.assertEqual(len(rows), 4)
        self.assertEqual(self.ledger.spend()["daily"], 400_000)

    def test_shared_budget_across_users(self):
        self._reserve("a", 400_000, user="user-alice")
        with self.assertRaises(BudgetExceeded):
            self._reserve("b", 700_000, user="user-bob")
        self.assertEqual(self.ledger.spend()["daily"], 400_000)

    def test_settle_releases_the_unused_ceiling(self):
        self._reserve("call", 150_000)
        self.ledger.mark_dispatched("call")
        self.ledger.settle_call("call", 1_000)
        self.ledger.settle_call("call", 9_000)
        self.assertEqual(self.ledger.spend()["daily"], 1_000)
        self.assertEqual(self.ledger.recent_calls(1)[0]["state"], "settled")

    def test_release_and_hold(self):
        self._reserve("rel", 150_000)
        self.ledger.release_call("rel")
        self.assertEqual(self.ledger.spend()["daily"], 0)
        self._reserve("hold", 150_000)
        self.ledger.mark_dispatched("hold")
        self.ledger.hold_call("hold")
        self.assertEqual(self.ledger.spend()["daily"], 150_000)
        self.assertEqual(self.ledger.spend()["held"], 150_000)
        with self.assertRaises(CallFinished):
            self.ledger.release_call("hold")
        held = self.ledger.hold_call("hold")
        self.assertEqual(held["state"], "held")

    def test_actual_above_reserve_pauses(self):
        self._reserve("hot", 1_000)
        self.ledger.mark_dispatched("hot")
        self.ledger.settle_call("hot", 50_000)
        self.assertEqual(self.ledger.spend()["daily"], 50_000)
        self.assertTrue(self.ledger.status()["paused"])
        with self.assertRaises(SponsoredPaused):
            self._reserve("next", 1_000)

    def test_parallel_quota(self):
        barrier = threading.Barrier(6)
        created = []
        limited = []

        def attempt(index: int):
            try:
                barrier.wait(timeout=5)
                job, is_new = self.ledger.begin_sponsored_job(
                    user_id="user-alice",
                    username="alice",
                    idempotency_key=f"idem-{index}",
                    spec=spec(caption=f"caption {index}"),
                    user_daily_limit=2,
                    daily_budget_micros=10_000_000,
                    monthly_budget_micros=10_000_000,
                )
                if is_new:
                    created.append(job["id"])
            except QuotaExceeded:
                limited.append(index)

        threads = [threading.Thread(target=attempt, args=(i,)) for i in range(6)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
        self.assertEqual(len(created), 2)
        self.assertEqual(len(limited), 4)
        self.assertEqual(self.ledger.quota_used("user-alice"), 2)
        self.assertEqual(self.ledger.quota_used("user-bob"), 0)

    def test_idempotent_job_and_payload_conflict(self):
        first, created = self.ledger.begin_sponsored_job(
            user_id="user-alice",
            username="alice",
            idempotency_key="idem-same",
            spec=spec(),
            user_daily_limit=3,
            daily_budget_micros=10_000_000,
            monthly_budget_micros=10_000_000,
        )
        again, created_again = self.ledger.begin_sponsored_job(
            user_id="user-alice",
            username="alice",
            idempotency_key="idem-same",
            spec=spec(),
            user_daily_limit=3,
            daily_budget_micros=10_000_000,
            monthly_budget_micros=10_000_000,
        )
        self.assertTrue(created)
        self.assertFalse(created_again)
        self.assertEqual(first["id"], again["id"])
        self.assertEqual(self.ledger.quota_used("user-alice"), 1)
        self.ledger.pause("maintenance")
        paused, _ = self.ledger.begin_sponsored_job(
            user_id="user-alice",
            username="alice",
            idempotency_key="idem-same",
            spec=spec(),
            user_daily_limit=3,
            daily_budget_micros=10_000_000,
            monthly_budget_micros=10_000_000,
        )
        self.assertEqual(paused["id"], first["id"])
        with self.assertRaises(IdempotencyConflict):
            self.ledger.begin_sponsored_job(
                user_id="user-alice",
                username="alice",
                idempotency_key="idem-same",
                spec=spec(caption="different"),
                user_daily_limit=3,
                daily_budget_micros=10_000_000,
                monthly_budget_micros=10_000_000,
            )


if __name__ == "__main__":
    unittest.main()
