from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime
from sqlalchemy.sql import func

from app.database import Base


class Centre(Base):
    __tablename__ = "centres"

    id = Column(Integer, primary_key=True, index=True)

    code = Column(String(20), unique=True, nullable=False, index=True)
    name = Column(String(150), nullable=False)

    district = Column(String(100), nullable=False)
    state = Column(String(100), nullable=False)

    address = Column(String(255), nullable=True)

    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)

    daily_capacity = Column(Integer, nullable=False, default=100)
    active_counters = Column(Integer, nullable=False, default=1)

    average_processing_minutes = Column(
        Float,
        nullable=False,
        default=8.0,
    )

    opening_time = Column(
        String(10),
        nullable=False,
        default="09:00",
    )

    closing_time = Column(
        String(10),
        nullable=False,
        default="17:00",
    )

    status = Column(
        String(30),
        nullable=False,
        default="Operational",
    )

    is_active = Column(
        Boolean,
        nullable=False,
        default=True,
    )

    created_at = Column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )