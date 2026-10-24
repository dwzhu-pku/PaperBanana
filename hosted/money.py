"""Integer USD micros. A micro is one millionth of a dollar."""

from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP


def usd_to_micros(value: object) -> int:
    amount = Decimal(str(value))
    micros = (amount * Decimal(1_000_000)).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
    return int(micros)


def micros_to_usd(micros: int) -> str:
    return f"{Decimal(int(micros)) / Decimal(1_000_000):.6f}"
