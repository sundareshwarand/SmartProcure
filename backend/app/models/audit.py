from sqlalchemy import Column, Integer, String, Boolean, DateTime, JSON
from sqlalchemy.sql import func

from app.database import Base


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)

    actor_id = Column(
        Integer,
        nullable=True,
        index=True,
    )

    actor_role = Column(
        String(30),
        nullable=True,
    )

    centre_id = Column(
        Integer,
        nullable=True,
        index=True,
    )

    action = Column(
        String(100),
        nullable=False,
        index=True,
    )

    target_type = Column(
        String(50),
        nullable=True,
    )

    target_id = Column(
        String(50),
        nullable=True,
    )

    success = Column(
        Boolean,
        nullable=False,
        default=True,
    )

    failure_reason = Column(
        String(500),
        nullable=True,
    )

    metadata_json = Column(
        JSON,
        nullable=True,
    )

    created_at = Column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )