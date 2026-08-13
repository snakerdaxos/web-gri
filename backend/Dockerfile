# GRI API image.
# Uses the official uv-from-GHCR Docker pattern. asyncmy / bcrypt / greenlet
# all ship manylinux cp312 wheels (verified Aug 2026), so NO build-essential /
# default-libmysqlclient-dev / pkg-config is needed on the standard x86_64 build.
# Alembic is deferred to Phase 3 -> CMD is just `uvicorn` (no `alembic upgrade head`).

FROM python:3.12-slim

# uv binary from the official image (recommended over `pip install uv`)
COPY --from=ghcr.io/astral-sh/uv:0.12 /uv /uvx /bin/

# Compile bytecode (faster startup), link mode copy (silences cache-on-separate-fs
# warnings), pin the venv location so PATH is stable.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/app/.venv

WORKDIR /app

# Layer 1: install deps ONLY (cached unless uv.lock / pyproject.toml change).
# --no-install-project installs just the dependencies, not the project itself,
# so this layer is reused across source changes.
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev

# Layer 2: copy source + install the project itself.
COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev

# Non-root user (security hygiene).
RUN useradd --create-home --uid 1000 appuser && chown -R appuser /app
USER appuser

# Put the venv on PATH so `uvicorn` resolves directly.
ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000
# CMD is uvicorn only — `alembic upgrade head` is added in Phase 3 when migrations exist.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
