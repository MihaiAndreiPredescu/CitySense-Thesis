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


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
