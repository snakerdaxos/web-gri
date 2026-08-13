"""INFR-01 integration test: charset utf8mb4, tz -05:00, round-trip accented+emoji.

Uses the same SQLAlchemy async engine the app uses (app.core.db.engine) so we
exercise the real driver path (asyncmy) and the real pool config.
"""

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine

from app.core.db import engine


async def test_db_charset_tz_and_unicode():
    """Assert server-level charset=utf8mb4, global tz=-05:00, and that a
    4-byte + accented string round-trips intact through the asyncmy driver.
    """
    expected = "Açaí 🍜 café Bogotá"

    # engine is the app's singleton; importing it re-uses pool config
    eng: AsyncEngine = engine

    async with eng.begin() as conn:
        # Server-level settings (set at mysql boot via docker-compose `command:`)
        row = (
            await conn.execute(
                text(
                    "SELECT @@character_set_database AS charset, "
                    "@@collation_database AS collation, "
                    "@@global.time_zone AS tz"
                )
            )
        ).one()
        assert row.charset == "utf8mb4", f"charset={row.charset!r}"
        assert row.collation == "utf8mb4_unicode_ci", f"collation={row.collation!r}"
        assert row.tz == "-05:00", f"tz={row.tz!r}"

        # Round-trip an accented + 4-byte (emoji) string
        await conn.execute(
            text(
                "CREATE TABLE IF NOT EXISTS infra_probe "
                "(v VARCHAR(50) CHARACTER SET utf8mb4) ENGINE=InnoDB"
            )
        )
        await conn.execute(text("TRUNCATE TABLE infra_probe"))
        await conn.execute(
            text("INSERT INTO infra_probe (v) VALUES (:s)"),
            {"s": expected},
        )
        got = (
            await conn.execute(text("SELECT v FROM infra_probe"))
        ).scalar_one()
        assert got == expected, f"round-trip mismatch: got={got!r}"
