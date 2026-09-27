from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean
from sqlalchemy.sql import func

from app.database import Base


class Procurement(Base):
    __tablename__ = "procurements"

    id = Column(Integer, primary_key=True, index=True)

    procurement_code = Column(
        String(30),
        unique=True,
        nullable=False,
        index=True,
    )

    booking_id = Column(Integer, nullable=False, index=True)
    farmer_id = Column(Integer, nullable=False, index=True)
    centre_id = Column(Integer, nullable=False, index=True)

    crop = Column(String(100), nullable=False)

    quantity_kg = Column(Float, nullable=False)

    actual_weight_kg = Column(Float, nullable=True)

    rate_per_kg = Column(Float, nullable=False)

    gross_amount = Column(Float, nullable=False)

    moisture_percentage = Column(Float, nullable=True)

    foreign_matter_percentage = Column(Float, nullable=True)

    damaged_percentage = Column(Float, nullable=True)

    quality_grade = Column(String(30), nullable=True)

    quality_remarks = Column(String(500), nullable=True)

    quality_passed = Column(Boolean, nullable=True)

    deductions = Column(Float, nullable=False, default=0)

    net_payable = Column(Float, nullable=True)

    status = Column(
        String(30),
        nullable=False,
        default="In Progress",
        index=True,
    )

    weighing_completed_at = Column(DateTime, nullable=True)

    quality_checked_at = Column(DateTime, nullable=True)

    amount_calculated_at = Column(DateTime, nullable=True)

    completed_at = Column(DateTime, nullable=True)

    created_at = Column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )