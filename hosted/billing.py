"""Sponsored-call billing. One reservation per provider attempt."""

from __future__ import annotations

from decimal import Decimal

from hosted.ledger import Ledger
from hosted.money import usd_to_micros


def micros_from_usage(usage: dict | None, reserved_micros: int) -> int:
    """Actual charge in micros. Unknown usage keeps the full reservation."""
    if not usage:
        return reserved_micros
    cost = usage.get("cost")
    if cost is None:
        return reserved_micros
    try:
        actual = usd_to_micros(cost)
    except (ArithmeticError, ValueError):
        return reserved_micros
    if actual < 0:
        return reserved_micros
    return actual


class SponsorBilling:
    def __init__(self, ledger: Ledger, settings, user_id: str, job_id: str):
        self.ledger = ledger
        self.settings = settings
        self.user_id = user_id
        self.job_id = job_id
        self.seq = 0
        self.dispatched_any = False
        self._reserved: dict[str, int] = {}

    async def reserve_attempt(self, *, kind: str, model: str) -> str:
        self.seq += 1
        key = f"call:{self.job_id}:{self.seq}"
        amount = (
            self.settings.text_reserve_micros
            if kind == "text"
            else self.settings.image_reserve_micros
        )
        self.ledger.reserve_call(
            idempotency_key=key,
            user_id=self.user_id,
            job_id=self.job_id,
            kind=kind,
            model=model,
            reserved_micros=amount,
            daily_budget_micros=self.settings.daily_budget_micros,
            monthly_budget_micros=self.settings.monthly_budget_micros,
        )
        self.ledger.mark_dispatched(key)
        self.dispatched_any = True
        self._reserved[key] = amount
        return key

    async def finish_attempt(self, key: str, *, outcome: str, usage: dict | None) -> None:
        if outcome == "success":
            reserved = self._reserved.get(key)
            if reserved is None:
                row = self.ledger.hold_call(key)
                reserved = int(row["reserved_micros"])
            actual = micros_from_usage(usage, reserved)
            self.ledger.settle_call(key, actual)
            return
        if outcome == "rejected":
            self.ledger.release_call(key)
            return
        self.ledger.hold_call(key)
