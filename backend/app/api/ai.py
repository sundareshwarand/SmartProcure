from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db

from app.ai.models import (
    QueuePredictionRequest,
    QueuePredictionResponse,
    DemandPredictionRequest,
    DemandPredictionResponse,
    DelayPredictionRequest,
    DelayPredictionResponse,
    CentreRecommendationRequest,
    CentreRecommendationResponse,
    SmartSlotRecommendationRequest,
)

from app.ai.predictor import predictor
from app.ai.service import recommend_smart_slots


router = APIRouter(
    prefix="/api/v1/ai",
    tags=["AI Intelligence"],
)


# =========================================================
# Helpers
# =========================================================

def safe_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def safe_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def calculate_wait_fallback(
    current_queue: int,
    average_processing_time: float,
    active_operators: int,
    expected_arrivals: int = 0,
):
    """
    Deterministic fallback based on real queue metrics.

    This is NOT random data.
    It is used only when the trained ML model
    cannot produce a prediction.
    """

    queue = max(current_queue, 0)

    processing_time = max(
        average_processing_time,
        1.0,
    )

    operators = max(
        active_operators,
        1,
    )

    effective_queue = (
        queue
        + max(expected_arrivals, 0) * 0.25
    )

    wait_minutes = (
        effective_queue
        * processing_time
        / operators
    )

    return max(
        0,
        round(wait_minutes),
    )


def calculate_congestion(
    current_queue: int,
    active_operators: int,
):
    queue = max(current_queue, 0)
    operators = max(active_operators, 1)

    load = queue / operators

    if load >= 10:
        return "High"

    if load >= 5:
        return "Medium"

    return "Low"


def calculate_utilization(
    current_queue: int,
    active_operators: int,
):
    queue = max(current_queue, 0)
    operators = max(active_operators, 1)

    utilization = (
        queue / operators
    ) * 10

    return round(
        min(max(utilization, 0), 100),
        2,
    )


def calculate_delay_risk(
    current_queue: int,
    average_processing_time: float,
    active_operators: int,
    expected_arrivals: int = 0,
):
    wait = calculate_wait_fallback(
        current_queue,
        average_processing_time,
        active_operators,
        expected_arrivals,
    )

    if wait >= 120:
        return "High"

    if wait >= 60:
        return "Medium"

    return "Low"


# =========================================================
# AI Health
# =========================================================

@router.get("/health")
def ai_health():
    return {
        "success": True,
        "service": "SmartProcure AI Intelligence",
        "status": "healthy",
        "models": {
            "wait_time": True,
            "demand": True,
            "delay": True,
        },
    }


# =========================================================
# Wait Time Prediction
# =========================================================

@router.post(
    "/predict/wait-time",
    response_model=QueuePredictionResponse,
)
def predict_wait_time(
    request: QueuePredictionRequest,
):
    try:
        current_queue = safe_int(
            request.current_queue
        )

        average_processing_time = safe_float(
            request.average_processing_time
        )

        active_operators = safe_int(
            request.active_operators
        )

        expected_arrivals = safe_int(
            getattr(
                request,
                "expected_arrivals",
                0,
            )
        )

        congestion = calculate_congestion(
            current_queue,
            active_operators,
        )

        utilization = calculate_utilization(
            current_queue,
            active_operators,
        )

        # Try trained ML model first.
        try:
            prediction = predictor.predict_wait_time(
                current_queue=current_queue,
                average_processing_time=average_processing_time,
                active_operators=active_operators,
                expected_arrivals=expected_arrivals,
            )

            if isinstance(prediction, dict):
                estimated_wait = prediction.get(
                    "estimated_wait_minutes",
                    prediction.get(
                        "wait_minutes",
                        None,
                    ),
                )
            else:
                estimated_wait = prediction

            estimated_wait = safe_float(
                estimated_wait,
                -1,
            )

            if estimated_wait < 0:
                raise ValueError(
                    "Invalid ML prediction"
                )

            model_used = "ML"

            estimated_wait = round(
                estimated_wait
            )

        except Exception:
            estimated_wait = calculate_wait_fallback(
                current_queue,
                average_processing_time,
                active_operators,
                expected_arrivals,
            )

            model_used = "rule-based-fallback"

        confidence = 0.90

        if active_operators <= 0:
            confidence = 0.50

        if current_queue == 0:
            confidence = 0.95

        return QueuePredictionResponse(
            estimated_wait_minutes=estimated_wait,
            congestion=congestion,
            utilization_percentage=utilization,
            confidence=confidence,
            model_used=model_used,
        )

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=(
                f"Wait-time prediction failed: {str(exc)}"
            ),
        )


# =========================================================
# Demand Prediction
# =========================================================

@router.post(
    "/predict/demand",
    response_model=DemandPredictionResponse,
)
def predict_demand(
    request: DemandPredictionRequest,
):
    try:
        hour = safe_int(
            request.hour
        )

        current_queue = safe_int(
            request.current_queue
        )

        active_operators = safe_int(
            request.active_operators
        )

        # Try ML model.
        try:
            prediction = predictor.predict_demand(
                hour=hour,
                current_queue=current_queue,
                active_operators=active_operators,
            )

            if isinstance(prediction, dict):
                predicted_demand = prediction.get(
                    "predicted_demand",
                    prediction.get(
                        "demand",
                        None,
                    ),
                )
            else:
                predicted_demand = prediction

            predicted_demand = safe_float(
                predicted_demand,
                -1,
            )

            if predicted_demand < 0:
                raise ValueError(
                    "Invalid demand prediction"
                )

            model_used = "ML"

        except Exception:
            hourly_base = max(
                current_queue,
                0,
            )

            operator_factor = max(
                active_operators,
                1,
            )

            predicted_demand = (
                hourly_base
                + operator_factor * 2
            )

            if 7 <= hour <= 11:
                predicted_demand *= 1.20

            elif 15 <= hour <= 18:
                predicted_demand *= 1.15

            else:
                predicted_demand *= 0.90

            predicted_demand = round(
                predicted_demand
            )

            model_used = "rule-based-fallback"

        if predicted_demand < 10:
            demand_level = "Low"

        elif predicted_demand < 30:
            demand_level = "Medium"

        else:
            demand_level = "High"

        return DemandPredictionResponse(
            predicted_demand=predicted_demand,
            demand_level=demand_level,
            model_used=model_used,
        )

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=(
                f"Demand prediction failed: {str(exc)}"
            ),
        )


# =========================================================
# Delay Prediction
# =========================================================

@router.post(
    "/predict/delay",
    response_model=DelayPredictionResponse,
)
def predict_delay(
    request: DelayPredictionRequest,
):
    try:
        current_queue = safe_int(
            request.current_queue
        )

        average_processing_time = safe_float(
            request.average_processing_time
        )

        active_operators = safe_int(
            request.active_operators
        )

        expected_arrivals = safe_int(
            getattr(
                request,
                "expected_arrivals",
                0,
            )
        )

        # Try ML model.
        try:
            prediction = predictor.predict_delay(
                current_queue=current_queue,
                average_processing_time=average_processing_time,
                active_operators=active_operators,
                expected_arrivals=expected_arrivals,
            )

            if isinstance(prediction, dict):
                risk = prediction.get(
                    "delay_risk",
                    prediction.get(
                        "risk",
                        None,
                    ),
                )
            else:
                risk = prediction

            if risk is None:
                raise ValueError(
                    "Invalid delay prediction"
                )

            risk = str(risk)

            if risk not in [
                "Low",
                "Medium",
                "High",
            ]:
                raise ValueError(
                    "Invalid delay risk"
                )

            model_used = "ML"

        except Exception:
            risk = calculate_delay_risk(
                current_queue,
                average_processing_time,
                active_operators,
                expected_arrivals,
            )

            model_used = "rule-based-fallback"

        estimated_wait = calculate_wait_fallback(
            current_queue,
            average_processing_time,
            active_operators,
            expected_arrivals,
        )

        return DelayPredictionResponse(
            delay_risk=risk,
            estimated_delay_minutes=estimated_wait,
            model_used=model_used,
        )

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=(
                f"Delay prediction failed: {str(exc)}"
            ),
        )


# =========================================================
# Smart Centre Recommendation
# =========================================================

@router.post(
    "/recommend-centre",
    response_model=CentreRecommendationResponse,
)
def recommend_centre(
    request: CentreRecommendationRequest,
    db: Session = Depends(get_db),
):
    """
    Recommend procurement centres based on
    location, queue and congestion.
    """

    try:
        from app.ai.service import ai_service

        recommendations = ai_service.recommend_centres(
            db=db,
            latitude=request.latitude,
            longitude=request.longitude,
        )

        if recommendations is None:
            recommendations = []

        return CentreRecommendationResponse(
            recommendations=recommendations,
        )

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=(
                f"Centre recommendation failed: {str(exc)}"
            ),
        )


# =========================================================
# AI SMART SLOT RECOMMENDATION
# =========================================================

@router.post(
    "/recommend-slot",
)
def recommend_slot(
    request: SmartSlotRecommendationRequest,
    db: Session = Depends(get_db),
):
    """
    AI-powered smart slot recommendation.

    Considers:
    - Booking date
    - Crop
    - Quantity
    - Centre capacity
    - Existing bookings
    - Expected waiting time
    - Congestion
    - Distance when location is provided

    Returns the best available recommendation
    together with alternative slots.
    """

    try:

        if request.quantity_kg <= 0:
            return {
                "success": False,
                "message": "Quantity must be greater than zero",
                "recommendations": [],
                "best_recommendation": None,
            }

        recommendations = recommend_smart_slots(
            db=db,
            booking_date=request.booking_date,
            crop=request.crop,
            quantity_kg=request.quantity_kg,
            latitude=request.latitude,
            longitude=request.longitude,
        )

        return {
            "success": True,
            "booking_date": str(
                request.booking_date
            ),
            "crop": request.crop,
            "quantity_kg": request.quantity_kg,
            "recommendations": recommendations,
            "best_recommendation": (
                recommendations[0]
                if recommendations
                else None
            ),
        }

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=(
                f"Smart slot recommendation failed: {str(exc)}"
            ),
        )