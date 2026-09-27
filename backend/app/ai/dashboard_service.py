from datetime import datetime
from math import sqrt
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from app.models.booking import Booking
from app.models.centre import Centre


# ============================================================
# SMARTPROCURE AI DASHBOARD SERVICE
# ============================================================
#
# This service uses the existing Booking + Centre database
# models. It intentionally does NOT depend on a Queue model.
#
# Main responsibilities:
#   1. Live queue analysis
#   2. Wait-time prediction
#   3. Centre utilization
#   4. Congestion detection
#   5. Delay-risk prediction
#   6. Demand forecasting
#   7. AI action recommendation
#   8. Smart centre recommendation
#
# ============================================================


# ------------------------------------------------------------
# STATUS DEFINITIONS
# ------------------------------------------------------------

WAITING_STATUSES = {
    "waiting",
    "queued",
    "checked in",
    "checked_in",
    "booked",
    "called",
}

PROCESSING_STATUSES = {
    "processing",
    "in progress",
    "in_progress",
}

COMPLETED_STATUSES = {
    "completed",
}

IGNORED_STATUSES = {
    "cancelled",
    "canceled",
    "no show",
    "no_show",
}


# ============================================================
# SAFE CONVERSION HELPERS
# ============================================================

def _safe_int(
    value: Any,
    default: int = 0,
) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _safe_float(
    value: Any,
    default: float = 0.0,
) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _normalise_status(
    value: Any,
) -> str:
    return str(
        value or ""
    ).strip().lower()


# ============================================================
# CENTRE HELPERS
# ============================================================

def _get_centre_name(
    centre: Centre,
) -> str:
    name = getattr(
        centre,
        "name",
        None,
    )

    if name:
        return str(name)

    centre_name = getattr(
        centre,
        "centre_name",
        None,
    )

    if centre_name:
        return str(centre_name)

    code = getattr(
        centre,
        "code",
        None,
    )

    if code:
        return str(code)

    return f"Centre {centre.id}"


def _get_capacity(
    centre: Centre,
) -> int:
    capacity = getattr(
        centre,
        "capacity",
        100,
    )

    return max(
        _safe_int(
            capacity,
            100,
        ),
        1,
    )


def _get_processing_time(
    centre: Centre,
) -> float:
    processing_time = getattr(
        centre,
        "average_processing_time",
        7.0,
    )

    processing_time = _safe_float(
        processing_time,
        7.0,
    )

    return max(
        processing_time,
        1.0,
    )


def _get_coordinates(
    centre: Centre,
):
    latitude = getattr(
        centre,
        "latitude",
        None,
    )

    longitude = getattr(
        centre,
        "longitude",
        None,
    )

    if (
        latitude is None
        or longitude is None
    ):
        return None, None

    return (
        _safe_float(latitude),
        _safe_float(longitude),
    )


# ============================================================
# DISTANCE CALCULATION
# ============================================================

def _distance_km(
    latitude1: Optional[float],
    longitude1: Optional[float],
    latitude2: Optional[float],
    longitude2: Optional[float],
):
    if (
        latitude1 is None
        or longitude1 is None
        or latitude2 is None
        or longitude2 is None
    ):
        return None

    try:
        latitude_difference = (
            float(latitude1)
            - float(latitude2)
        )

        longitude_difference = (
            float(longitude1)
            - float(longitude2)
        )

        distance = (
            sqrt(
                latitude_difference
                * latitude_difference
                +
                longitude_difference
                * longitude_difference
            )
            * 111.0
        )

        return round(
            distance,
            2,
        )

    except Exception:
        return None


# ============================================================
# LIVE BOOKING / QUEUE SNAPSHOT
# ============================================================

def get_queue_snapshot(
    db: Session,
    centre_id: int,
) -> Dict[str, Any]:

    bookings = (
        db.query(Booking)
        .filter(
            Booking.centre_id == centre_id,
        )
        .all()
    )

    waiting = 0
    processing = 0
    completed = 0
    ignored = 0

    for booking in bookings:

        status = _normalise_status(
            getattr(
                booking,
                "status",
                None,
            )
        )

        if status in IGNORED_STATUSES:
            ignored += 1
            continue

        if status in WAITING_STATUSES:
            waiting += 1

        elif status in PROCESSING_STATUSES:
            processing += 1

        elif status in COMPLETED_STATUSES:
            completed += 1

    active = (
        waiting
        + processing
    )

    return {
        "waiting": waiting,
        "processing": processing,
        "completed": completed,
        "active": active,
        "ignored": ignored,
        "total_records": len(bookings),
    }


# ============================================================
# WAIT-TIME PREDICTION
# ============================================================

def calculate_wait_time(
    waiting: int,
    processing: int,
    average_processing_time: float,
) -> int:

    # At least one active processing capacity is assumed.
    active_processing_capacity = max(
        processing,
        1,
    )

    estimated_wait = (
        waiting
        * average_processing_time
        / active_processing_capacity
    )

    return max(
        int(round(estimated_wait)),
        0,
    )


# ============================================================
# UTILIZATION
# ============================================================

def calculate_utilization(
    waiting: int,
    processing: int,
    capacity: int,
) -> float:

    active = (
        waiting
        + processing
    )

    if capacity <= 0:
        return 0.0

    utilization = (
        active
        / capacity
    ) * 100.0

    utilization = min(
        max(
            utilization,
            0.0,
        ),
        100.0,
    )

    return round(
        utilization,
        1,
    )


# ============================================================
# CONGESTION ANALYSIS
# ============================================================

def calculate_congestion(
    utilization: float,
    waiting: int,
) -> str:

    if (
        utilization >= 80.0
        or waiting >= 30
    ):
        return "High"

    if (
        utilization >= 50.0
        or waiting >= 15
    ):
        return "Medium"

    return "Low"


# ============================================================
# DELAY-RISK ANALYSIS
# ============================================================

def calculate_delay_risk(
    waiting: int,
    estimated_wait: int,
    utilization: float,
) -> str:

    risk_score = 0

    # Queue pressure.
    if waiting >= 30:
        risk_score += 50

    elif waiting >= 15:
        risk_score += 30

    elif waiting >= 5:
        risk_score += 15

    # Estimated waiting time.
    if estimated_wait >= 60:
        risk_score += 30

    elif estimated_wait >= 30:
        risk_score += 20

    elif estimated_wait >= 15:
        risk_score += 10

    # Centre utilization.
    if utilization >= 80:
        risk_score += 20

    elif utilization >= 60:
        risk_score += 10

    if risk_score >= 70:
        return "High"

    if risk_score >= 35:
        return "Medium"

    return "Low"


# ============================================================
# DEMAND FORECAST
# ============================================================

def calculate_demand(
    waiting: int,
    processing: int,
    current_hour: int,
) -> float:

    current_load = (
        waiting
        + processing
    )

    # Procurement demand varies during the day.
    #
    # Morning peak:
    #       08:00 - 11:00
    #
    # Midday:
    #       11:00 - 14:00
    #
    # Afternoon:
    #       14:00 - 17:00
    #
    # Evening:
    #       otherwise

    if 8 <= current_hour < 11:
        multiplier = 1.30

    elif 11 <= current_hour < 14:
        multiplier = 1.10

    elif 14 <= current_hour < 17:
        multiplier = 1.25

    else:
        multiplier = 0.80

    predicted_demand = (
        current_load
        * multiplier
    )

    return round(
        max(
            predicted_demand,
            0.0,
        ),
        1,
    )


def get_demand_level(
    predicted_demand: float,
) -> str:

    if predicted_demand >= 30:
        return "High"

    if predicted_demand >= 15:
        return "Medium"

    return "Low"


# ============================================================
# AI ACTION RECOMMENDATION
# ============================================================

def build_action_recommendation(
    congestion: str,
    delay_risk: str,
    waiting: int,
    estimated_wait: int,
) -> Dict[str, str]:

    if (
        congestion == "High"
        or delay_risk == "High"
    ):
        return {
            "priority": "URGENT",
            "action": (
                "Open an additional "
                "procurement counter"
            ),
            "reason": (
                f"{waiting} farmers are waiting "
                f"and estimated wait is "
                f"{estimated_wait} minutes."
            ),
        }

    if (
        congestion == "Medium"
        or delay_risk == "Medium"
    ):
        return {
            "priority": "ATTENTION",
            "action": (
                "Prepare an additional "
                "procurement counter"
            ),
            "reason": (
                f"{waiting} farmers are waiting. "
                "Queue pressure is increasing."
            ),
        }

    return {
        "priority": "NORMAL",
        "action": (
            "Continue normal operations"
        ),
        "reason": (
            "Current queue pressure is "
            "within the normal operating range."
        ),
    }


# ============================================================
# AI CONFIDENCE
# ============================================================

def calculate_confidence(
    total_records: int,
    processing: int,
) -> float:

    confidence = 70.0

    if total_records >= 5:
        confidence += 10.0

    if total_records >= 10:
        confidence += 10.0

    if processing > 0:
        confidence += 5.0

    return min(
        confidence,
        95.0,
    )


# ============================================================
# COMPLETION RATE
# ============================================================

def calculate_completion_percentage(
    waiting: int,
    processing: int,
    completed: int,
) -> float:

    total = (
        waiting
        + processing
        + completed
    )

    if total <= 0:
        return 0.0

    return round(
        (
            completed
            / total
        )
        * 100.0,
        1,
    )


# ============================================================
# SINGLE CENTRE AI ANALYSIS
# ============================================================

def analyse_centre(
    db: Session,
    centre: Centre,
) -> Dict[str, Any]:

    snapshot = get_queue_snapshot(
        db,
        centre.id,
    )

    waiting = snapshot["waiting"]
    processing = snapshot["processing"]
    completed = snapshot["completed"]

    capacity = _get_capacity(
        centre
    )

    average_processing_time = (
        _get_processing_time(
            centre
        )
    )

    estimated_wait = calculate_wait_time(
        waiting=waiting,
        processing=processing,
        average_processing_time=average_processing_time,
    )

    utilization = calculate_utilization(
        waiting=waiting,
        processing=processing,
        capacity=capacity,
    )

    congestion = calculate_congestion(
        utilization=utilization,
        waiting=waiting,
    )

    delay_risk = calculate_delay_risk(
        waiting=waiting,
        estimated_wait=estimated_wait,
        utilization=utilization,
    )

    current_hour = datetime.now().hour

    predicted_demand = calculate_demand(
        waiting=waiting,
        processing=processing,
        current_hour=current_hour,
    )

    demand_level = get_demand_level(
        predicted_demand
    )

    confidence = calculate_confidence(
        total_records=snapshot["total_records"],
        processing=processing,
    )

    completion_percentage = (
        calculate_completion_percentage(
            waiting=waiting,
            processing=processing,
            completed=completed,
        )
    )

    action = build_action_recommendation(
        congestion=congestion,
        delay_risk=delay_risk,
        waiting=waiting,
        estimated_wait=estimated_wait,
    )

    return {
        "waiting": waiting,
        "processing": processing,
        "completed": completed,
        "active": snapshot["active"],
        "total_records": snapshot["total_records"],
        "estimated_wait_minutes": estimated_wait,
        "utilization_percentage": utilization,
        "congestion": congestion,
        "delay_risk": delay_risk,
        "predicted_demand": predicted_demand,
        "demand_level": demand_level,
        "confidence": confidence,
        "completion_percentage": completion_percentage,
        "recommendation": action,
    }


# ============================================================
# MAIN AI DASHBOARD
# ============================================================

def build_ai_dashboard(
    db: Session,
    centre_id: int,
) -> Dict[str, Any]:

    centre = (
        db.query(Centre)
        .filter(
            Centre.id == centre_id,
        )
        .first()
    )

    if not centre:
        return {
            "success": False,
            "message": "Centre not found",
        }

    analysis = analyse_centre(
        db=db,
        centre=centre,
    )

    latitude, longitude = (
        _get_coordinates(
            centre
        )
    )

    return {
        "success": True,

        "generated_at": (
            datetime.now().isoformat()
        ),

        "centre": {
            "id": centre.id,
            "name": _get_centre_name(
                centre
            ),
            "capacity": _get_capacity(
                centre
            ),
            "average_processing_time": (
                _get_processing_time(
                    centre
                )
            ),
            "latitude": latitude,
            "longitude": longitude,
        },

        "live": {
            "waiting": analysis["waiting"],
            "processing": analysis["processing"],
            "completed": analysis["completed"],
            "active": analysis["active"],
            "total_records": (
                analysis["total_records"]
            ),
            "utilization_percentage": (
                analysis[
                    "utilization_percentage"
                ]
            ),
            "completion_percentage": (
                analysis[
                    "completion_percentage"
                ]
            ),
        },

        "predictions": {
            "estimated_wait_minutes": (
                analysis[
                    "estimated_wait_minutes"
                ]
            ),
            "congestion": (
                analysis["congestion"]
            ),
            "delay_risk": (
                analysis["delay_risk"]
            ),
            "predicted_demand": (
                analysis["predicted_demand"]
            ),
            "demand_level": (
                analysis["demand_level"]
            ),
            "confidence": (
                analysis["confidence"]
            ),
        },

        "recommendation": (
            analysis["recommendation"]
        ),

        "intelligence": {
            "current_hour": datetime.now().hour,
            "engine": (
                "SmartProcure "
                "Operational Intelligence v1"
            ),
            "data_source": (
                "MySQL Booking + Centre data"
            ),
            "analysis": [
                "Live queue pressure",
                "Centre utilization",
                "Wait-time estimation",
                "Demand forecasting",
                "Delay-risk analysis",
                "Operational recommendation",
            ],
        },
    }


# ============================================================
# SMART CENTRE RECOMMENDATION
# ============================================================

def recommend_centres(
    db: Session,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
) -> List[Dict[str, Any]]:

    centres = (
        db.query(Centre)
        .all()
    )

    recommendations = []

    for centre in centres:

        analysis = analyse_centre(
            db=db,
            centre=centre,
        )

        centre_latitude, centre_longitude = (
            _get_coordinates(
                centre
            )
        )

        distance = _distance_km(
            latitude1=latitude,
            longitude1=longitude,
            latitude2=centre_latitude,
            longitude2=centre_longitude,
        )

        # ----------------------------------------------------
        # Recommendation score
        # ----------------------------------------------------

        score = 100.0

        # Lower wait = better.
        score -= min(
            analysis[
                "estimated_wait_minutes"
            ],
            60,
        ) * 0.5

        # Lower utilization = better.
        score -= min(
            analysis[
                "utilization_percentage"
            ],
            100,
        ) * 0.2

        # Congestion penalty.
        if analysis["congestion"] == "Medium":
            score -= 10.0

        elif analysis["congestion"] == "High":
            score -= 25.0

        # Distance penalty if location is available.
        if distance is not None:
            score -= min(
                distance,
                20,
            ) * 0.5

        score = round(
            max(
                score,
                0.0,
            ),
            1,
        )

        recommendations.append(
            {
                "centre_id": centre.id,

                "centre_name": (
                    _get_centre_name(
                        centre
                    )
                ),

                "queue_length": (
                    analysis["waiting"]
                ),

                "processing": (
                    analysis["processing"]
                ),

                "estimated_wait_minutes": (
                    analysis[
                        "estimated_wait_minutes"
                    ]
                ),

                "congestion": (
                    analysis["congestion"]
                ),

                "utilization_percentage": (
                    analysis[
                        "utilization_percentage"
                    ]
                ),

                "delay_risk": (
                    analysis["delay_risk"]
                ),

                "distance_km": distance,

                "recommendation_score": score,
            }
        )

    recommendations.sort(
        key=lambda item: (
            -item["recommendation_score"],
            item["estimated_wait_minutes"],
            item["queue_length"],
        )
    )

    return recommendations[:5]


# ============================================================
# SIMPLE AI HEALTH INFORMATION
# ============================================================

def get_ai_engine_status() -> Dict[str, Any]:
    return {
        "online": True,
        "engine": (
            "SmartProcure "
            "Operational Intelligence v1"
        ),
        "features": [
            "Queue analysis",
            "Wait-time prediction",
            "Demand forecasting",
            "Delay-risk analysis",
            "Centre recommendation",
            "Operational recommendations",
        ],
        "database": "MySQL",
        "mode": "Database-driven",
    }