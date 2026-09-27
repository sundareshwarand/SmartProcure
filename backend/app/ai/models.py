from datetime import date

from pydantic import BaseModel, Field


# =========================================================
# Wait Time Prediction
# =========================================================

class QueuePredictionRequest(BaseModel):
    current_queue: int = Field(
        default=0,
        ge=0,
    )

    average_processing_time: float = Field(
        default=7.0,
        gt=0,
    )

    active_operators: int = Field(
        default=1,
        ge=1,
    )

    expected_arrivals: int = Field(
        default=0,
        ge=0,
    )


class QueuePredictionResponse(BaseModel):
    estimated_wait_minutes: int

    congestion: str

    utilization_percentage: float

    confidence: float

    model_used: str


# =========================================================
# Demand Prediction
# =========================================================

class DemandPredictionRequest(BaseModel):
    hour: int = Field(
        default=12,
        ge=0,
        le=23,
    )

    current_queue: int = Field(
        default=0,
        ge=0,
    )

    active_operators: int = Field(
        default=1,
        ge=1,
    )


class DemandPredictionResponse(BaseModel):
    predicted_demand: float

    demand_level: str

    model_used: str


# =========================================================
# Delay Prediction
# =========================================================

class DelayPredictionRequest(BaseModel):
    current_queue: int = Field(
        default=0,
        ge=0,
    )

    average_processing_time: float = Field(
        default=7.0,
        gt=0,
    )

    active_operators: int = Field(
        default=1,
        ge=1,
    )

    expected_arrivals: int = Field(
        default=0,
        ge=0,
    )


class DelayPredictionResponse(BaseModel):
    delay_risk: str

    estimated_delay_minutes: int

    model_used: str


# =========================================================
# Centre Recommendation
# =========================================================

class CentreRecommendationRequest(BaseModel):
    latitude: float

    longitude: float


class CentreRecommendation(BaseModel):
    centre_id: int

    centre_name: str

    distance_km: float

    queue_length: int

    estimated_wait_minutes: int

    congestion: str

    utilization_percentage: float


class CentreRecommendationResponse(BaseModel):
    recommendations: list[CentreRecommendation]


# =========================================================
# Smart Slot Recommendation
# =========================================================

class SmartSlotRecommendationRequest(BaseModel):
    booking_date: date

    crop: str = Field(
        min_length=1,
    )

    quantity_kg: float = Field(
        gt=0,
    )

    latitude: float | None = None

    longitude: float | None = None


class SmartSlotRecommendation(BaseModel):
    centre_id: int

    centre_name: str

    slot_id: int

    slot_start: str

    slot_end: str

    capacity: int

    booked: int

    available: int

    expected_wait_minutes: int

    congestion_level: str

    distance_km: float | None = None

    recommendation_score: float


class SmartSlotRecommendationResponse(BaseModel):
    success: bool

    booking_date: date

    recommendations: list[
        SmartSlotRecommendation
    ]

    best_recommendation: (
        SmartSlotRecommendation | None
    ) = None