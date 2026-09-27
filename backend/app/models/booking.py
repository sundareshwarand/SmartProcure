from sqlalchemy import Column, Integer, String, Float, Date, DateTime
from sqlalchemy.sql import func

from app.database import Base


class Booking(Base):
    __tablename__ = "bookings"

    id = Column(Integer, primary_key=True, index=True)

    booking_code = Column(
        String(30),
        unique=True,
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

    crop = Column(String(100), nullable=False)

    quantity_kg = Column(
        Float,
        nullable=False,
    )

    booking_date = Column(
        Date,
        nullable=False,
    )

    slot_start = Column(
        String(10),
        nullable=False,
    )

    slot_end = Column(
        String(10),
        nullable=False,
    )

    token = Column(
        String(30),
        nullable=True,
        index=True,
    )

    queue_position = Column(
        Integer,
        nullable=True,
    )

    estimated_wait_minutes = Column(
        Integer,
        nullable=True,
    )

    status = Column(
        String(30),
        nullable=False,
        default="Booked",
        index=True,
    )

    created_at = Column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )

    updated_at = Column(
        DateTime,
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )