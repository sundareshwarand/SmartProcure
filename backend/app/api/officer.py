from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.database import get_db
from app.models.centre import Centre
from app.models.booking import Booking
from app.models.procurement import Procurement
from app.models.payment import Payment
from app.models.queue import QueueEntry

router = APIRouter(
    prefix="/api/v1/officer",
    tags=["Officer Dashboard"],
)


@router.get("/overview")
def officer_overview(db: Session = Depends(get_db)):
    centres = db.query(Centre).filter(Centre.is_active == True).all()

    total_capacity = sum(c.daily_capacity or 0 for c in centres)

    waiting = (
        db.query(QueueEntry)
        .filter(QueueEntry.status.in_(["Waiting", "Called"]))
        .count()
    )

    processing = (
        db.query(QueueEntry)
        .filter(QueueEntry.status == "Processing")
        .count()
    )

    completed = (
        db.query(QueueEntry)
        .filter(QueueEntry.status == "Completed")
        .count()
    )

    total_procured = (
        db.query(func.coalesce(func.sum(Procurement.quantity_kg), 0))
        .filter(Procurement.status == "Completed")
        .scalar()
    )

    total_payment = (
        db.query(func.coalesce(func.sum(Payment.amount), 0))
        .filter(Payment.status == "Paid")
        .scalar()
    )

    return {
        "success": True,
        "overview": {
            "total_centres": len(centres),
            "total_capacity": total_capacity,
            "waiting": waiting,
            "processing": processing,
            "completed": completed,
            "total_procured_kg": float(total_procured or 0),
            "total_paid": float(total_payment or 0),
        },
    }


@router.get("/centres")
def officer_centres(db: Session = Depends(get_db)):
    centres = (
        db.query(Centre)
        .filter(Centre.is_active == True)
        .order_by(Centre.id)
        .all()
    )

    result = []

    for centre in centres:
        waiting = (
            db.query(QueueEntry)
            .filter(
                QueueEntry.centre_id == centre.id,
                QueueEntry.status.in_(["Waiting", "Called"]),
            )
            .count()
        )

        processing = (
            db.query(QueueEntry)
            .filter(
                QueueEntry.centre_id == centre.id,
                QueueEntry.status == "Processing",
            )
            .count()
        )

        completed = (
            db.query(QueueEntry)
            .filter(
                QueueEntry.centre_id == centre.id,
                QueueEntry.status == "Completed",
            )
            .count()
        )

        utilization = 0

        if centre.daily_capacity:
            utilization = round(
                ((waiting + processing + completed) / centre.daily_capacity) * 100,
                2,
            )

        result.append(
            {
                "id": centre.id,
                "code": centre.code,
                "name": centre.name,
                "district": centre.district,
                "status": centre.status,
                "capacity": centre.daily_capacity,
                "waiting": waiting,
                "processing": processing,
                "completed": completed,
                "utilization": utilization,
                "average_processing_minutes": centre.average_processing_minutes,
            }
        )

    return {
        "success": True,
        "centres": result,
    }