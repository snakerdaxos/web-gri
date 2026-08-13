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

    @property
    def database_url(self) -> str:
        """SQLAlchemy async URL pointing at MySQL via asyncmy, utf8mb4 charset."""
        return (
            f"mysql+asyncmy://{self.DB_USER}:{self.DB_PASSWORD}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}?charset=utf8mb4"
        )


settings = Settings()
