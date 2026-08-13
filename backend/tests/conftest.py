"""Pytest fixtures for Wave 0 smoke tests.

The async_client fixture assumes the Docker stack is already running
(`docker compose up -d`). It points at http://localhost:8000 (the published
API port from docker-compose.yml).
"""

from collections.abc import AsyncGenerator

import pytest
import pytest_asyncio
import httpx


@pytest_asyncio.fixture
async def async_client() -> AsyncGenerator[httpx.AsyncClient, None]:
    """Yield an httpx AsyncClient pointing at the running API container."""
    async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
        yield client


# Keep pytest happy with the plugin import (silences unused-import on strict linters).
_ = pytest
