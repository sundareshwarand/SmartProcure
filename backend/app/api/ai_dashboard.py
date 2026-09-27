from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.ai.dashboard_service import (
    build_ai_dashboard,
    recommend_centres,
)


router = APIRouter(
    prefix="/api/v1/ai",
    tags=["AI Intelligence"],
)


# ============================================================
# AI DASHBOARD
# ============================================================

@router.get("/dashboard")
def ai_dashboard(
    centre_id: int = Query(
        default=1,
        ge=1,
    ),
    db: Session = Depends(get_db),
):
    return build_ai_dashboard(
        db=db,
        centre_id=centre_id,
    )


# ============================================================
# AI CENTRE RECOMMENDATION
# ============================================================

@router.post("/recommend-centre")
def ai_recommend_centre(
    payload: dict,
    db: Session = Depends(get_db),
):
    latitude = payload.get(
        "latitude"
    )

    longitude = payload.get(
        "longitude"
    )

    recommendations = recommend_centres(
        db=db,
        latitude=latitude,
        longitude=longitude,
    )

    return {
        "success": True,
        "recommendations": recommendations,
        "best_recommendation": (
            recommendations[0]
            if recommendations
            else None
        ),
    }


# ============================================================
# HEALTH CHECK
# ============================================================

@router.get("/health")
def ai_health():
    return {
        "success": True,
        "service": "SmartProcure AI",
        "status": "online",
        "engine": (
            "SmartProcure Operational Intelligence v1"
        ),
    }