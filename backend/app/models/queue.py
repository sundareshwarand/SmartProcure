from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.sql import func

from app.database import Base


class QueueEntry(Base):
    __tablename__ = "queue_entries"

    id = Column(Integer, primary_key=True, index=True)

    booking_id = Column(
        Integer,
        nullable=False,
        index=True,
    )

    farmer_id = Column(
        Integer,
        nullable=False,
        index=True,
    )

    centre_id = Column(
        Integer,
        nullable=False,
        index=True,
    )

    token = Column(
        String(30),
        nullable=False,
        index=True,
    )

    position = Column(
        Integer,
        nullable=False,
    )

    status = Column(
        String(30),
        nullable=False,
        default="Waiting",
        index=True,
    )

    checked_in_at = Column(
        DateTime,
        nullable=True,
    )

    called_at = Column(
        DateTime,
        nullable=True,
    )

    processing_started_at = Column(
        DateTime,
        nullable=True,
    )

    completed_at = Column(
        DateTime,
        nullable=True,
    )

    no_show_at = Column(
        DateTime,
        nullable=True,
    )

    created_at = Column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )