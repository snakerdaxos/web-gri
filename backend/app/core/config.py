"""Application configuration loaded from environment variables.

INFR-02 contract: changing these env vars (typically via .env or docker-compose)
changes the database connection with zero code edits. Parts-based (DB_HOST/PORT/
USER/PASSWORD/NAME) so each component is independently verifiable.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Database connection PARTS (INFR-02: change these via .env -> connection changes)
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_USER: str = "gri_app"
    DB_PASSWORD: str = ""
    DB_NAME: str = "gri"

    # App flags
    ENVIRONMENT: str = "development"  # development | production
    # Read but inert this phase. Phase 3 seeds the demo restaurant when True.
    DEMO_MODE: bool = False

    # --- Phase 2: auth + tenancy ---
    # JWT signing secret (HS256, single-secret architecture — ARCHITECTURE.md
    # Pattern 2). In prod this MUST be a strong random value; generate with:
    #   python -c "import secrets; print(secrets.token_urlsafe(48))"
    JWT_SECRET: str = "replace-me-with-a-long-random-string"
    ACCESS_TTL_MIN: int = 15        # access token lifetime (minutes)
    REFRESH_TTL_DAYS: int = 7       # refresh token lifetime (days)

    # Bootstrap super-admin: created idempotently on startup if absent.
    # None => bootstrap is skipped (dev convenience). Prod MUST set both.
    SUPER_ADMIN_EMAIL: str | None = None
    SUPER_ADMIN_PASSWORD: str | None = None

    # --- Phase 4: CORS (panel admin web origin, T-04-01) ---
    # Comma-separated browser origins allowed to call the API with credentials.
    # Explicit origins ONLY — allow_credentials=True forbids "*" (wildcard +
    # credentials is rejected at runtime and would leak cross-origin).
    # Phase 9 prod: set the panel's HTTPS domain(s), e.g. "https://panel.gri.com".
    CORS_ORIGINS: str = "http://localhost:5173"

    @property
    def database_url(self) -> str:
        """SQLAlchemy async URL pointing at MySQL via asyncmy, utf8mb4 charset."""
        return (
            f"mysql+asyncmy://{self.DB_USER}:{self.DB_PASSWORD}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}?charset=utf8mb4"
        )


settings = Settings()
