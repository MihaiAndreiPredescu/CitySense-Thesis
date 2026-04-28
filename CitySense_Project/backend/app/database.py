from __future__ import annotations

from collections.abc import Generator

from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker

from .config import get_settings
from .models import Base


settings = get_settings()

engine = create_engine(settings.database_url, future=True, pool_pre_ping=True)
SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False,
    class_=Session,
)


def initialize_database() -> None:
    with engine.begin() as connection:
        connection.execute(text("CREATE EXTENSION IF NOT EXISTS postgis"))
    Base.metadata.create_all(bind=engine)
    _ensure_report_columns()


def _ensure_report_columns() -> None:
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                ALTER TABLE reports
                ADD COLUMN IF NOT EXISTS last_photo_reported_at
                TIMESTAMP WITH TIME ZONE
                """
            )
        )
        connection.execute(
            text(
                """
                UPDATE reports
                SET last_photo_reported_at = COALESCE(updated_at, created_at, now())
                WHERE last_photo_reported_at IS NULL
                """
            )
        )
        connection.execute(
            text(
                """
                ALTER TABLE reports
                ALTER COLUMN last_photo_reported_at SET DEFAULT now()
                """
            )
        )
        connection.execute(
            text(
                """
                ALTER TABLE reports
                ALTER COLUMN last_photo_reported_at SET NOT NULL
                """
            )
        )


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
