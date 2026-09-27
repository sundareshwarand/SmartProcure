from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.grievance import Grievance

router = APIRouter(
    prefix="/api/v1/grievances",
    tags=["Grievances"],
)


@router.get("")
def get_grievances(
    farmer_id: int | None = None,
    db: Session = Depends(get_db),
):
    query = db.query(Grievance)

    if farmer_id:
        query = query.filter(Grievance.farmer_id == farmer_id)

    items = query.order_by(Grievance.id.desc()).all()

    return {
        "success": True,
        "count": len(items),
        "grievances": [
            {
                "id": g.id,
                "grievance_code": g.grievance_code,
                "farmer_id": g.farmer_id,
                "category": g.category,
                "description": g.description,
                "status": g.status,
                "resolution": g.resolution,
                "created_at": str(g.created_at),
            }
            for g in items
        ],
    }


@router.post("")
def create_grievance(
    farmer_id: int,
    category: str,
    description: str,
    db: Session = Depends(get_db),
):
    count = db.query(Grievance).count() + 1

    grievance = Grievance(
        grievance_code=f"GRV-2026-{count:04d}",
        farmer_id=farmer_id,
        category=category,
        description=description,
        status="Open",
    )

    db.add(grievance)
    db.commit()
    db.refresh(grievance)

    return {
        "success": True,
        "message": "Grievance submitted successfully",
        "grievance_code": grievance.grievance_code,
    }