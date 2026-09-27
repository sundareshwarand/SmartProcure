from sqlalchemy import Column, Integer, String, Float, DateTime
from sqlalchemy.sql import func

from app.database import Base


class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)

    procurement_id = Column(
        Integer,
        nullable=False,
        index=True,
    )

    farmer_id = Column(
        Integer,
        nullable=False,
        index=True,
    )

    amount = Column(
        Float,
        nullable=False,
    )

    method = Column(
        String(50),
        nullable=False,
        default="Bank Transfer",
    )

    status = Column(
        String(30),
        nullable=False,
        default="Pending",
        index=True,
    )

    transaction_reference = Column(
        String(100),
        nullable=True,
        unique=True,
    )

    initiated_at = Column(
        DateTime,
        nullable=True,
    )

    paid_at = Column(
        DateTime,
        nullable=True,
    )

    created_at = Column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )