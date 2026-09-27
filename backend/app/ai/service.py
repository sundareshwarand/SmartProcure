from math import radians, sin, cos, sqrt, atan2
from datetime import date

from app.models.booking import Booking
from app.models.centre import Centre


# =========================================================
# SMART SLOT CONFIGURATION
# =========================================================

SMART_SLOT_WINDOWS = [
    ("09:00", "10:00"),
    ("10:00", "11:00"),
    ("11:00", "12:00"),
    ("14:00", "15:00"),
    ("15:00", "16:00"),
]


# =========================================================
# BASIC HELPERS
# =========================================================

def _distance_km(
    lat1: float | None,
    lon1: float | None,
    lat2: float | None,
    lon2: float | None,
):
    if (
        lat1 is None
        or lon1 is None
        or lat2 is None
        or lon2 is None
    ):
        return None

    try:
        earth_radius = 6371.0

        dlat = radians(
            float(lat2) - float(lat1)
        )

        dlon = radians(
            float(lon2) - float(lon1)
        )

        a = (
            sin(dlat / 2) ** 2
            + cos(radians(float(lat1)))
            * cos(radians(float(lat2)))
            * sin(dlon / 2) ** 2
        )

        c = 2 * atan2(
            sqrt(a),
            sqrt(1 - a),
        )

        return round(
            earth_radius * c,
            2,
        )

    except Exception:
        return None


def _congestion_level(
    booked: int,
    capacity: int,
):
    if capacity <= 0:
        return "High"

    utilization = booked / capacity

    if utilization >= 0.80:
        return "High"

    if utilization >= 0.50:
        return "Medium"

    return "Low"


# =========================================================
# SMART SLOT RECOMMENDATION
# =========================================================

def recommend_smart_slots(
    db,
    booking_date: date,
    crop: str,
    quantity_kg: float,
    latitude: float | None = None,
    longitude: float | None = None,
):
    """
    Recommend available procurement centre slots.

    Uses:
    - Centre capacity
    - Existing bookings
    - Processing time
    - Slot availability
    - Congestion
    - Distance when coordinates are available
    """

    centres = (
        db.query(Centre)
        .order_by(Centre.id.asc())
        .all()
    )

    recommendations = []

    for centre in centres:

        # -------------------------------------------------
        # Centre capacity
        # -------------------------------------------------

        daily_capacity = max(
            1,
            int(
                getattr(
                    centre,
                    "capacity",
                    100,
                )
                or 100
            ),
        )

        average_processing_time = float(
            getattr(
                centre,
                "average_processing_time",
                7.0,
            )
            or 7.0
        )

        # Divide daily capacity between 5 slots.
        slot_capacity = max(
            1,
            daily_capacity // len(
                SMART_SLOT_WINDOWS
            ),
        )

        # -------------------------------------------------
        # Centre coordinates
        # -------------------------------------------------

        centre_latitude = getattr(
            centre,
            "latitude",
            None,
        )

        centre_longitude = getattr(
            centre,
            "longitude",
            None,
        )

        distance_km = _distance_km(
            latitude,
            longitude,
            centre_latitude,
            centre_longitude,
        )

        # -------------------------------------------------
        # Analyse every slot
        # -------------------------------------------------

        for slot_id, (
            start,
            end,
        ) in enumerate(
            SMART_SLOT_WINDOWS,
            start=1,
        ):

            existing_count = (
                db.query(Booking)
                .filter(
                    Booking.centre_id
                    == centre.id,

                    Booking.booking_date
                    == booking_date,

                    Booking.slot_start
                    == start,

                    Booking.slot_end
                    == end,

                    Booking.status.notin_(
                        [
                            "Cancelled",
                            "No Show",
                        ]
                    ),
                )
                .count()
            )

            available = max(
                0,
                slot_capacity
                - existing_count,
            )

            # Full slot cannot be recommended.
            if available <= 0:
                continue

            # -------------------------------------------------
            # Congestion
            # -------------------------------------------------

            congestion = _congestion_level(
                existing_count,
                slot_capacity,
            )

            # -------------------------------------------------
            # Estimated waiting time
            # -------------------------------------------------

            expected_wait_minutes = int(
                existing_count
                * average_processing_time
            )

            # -------------------------------------------------
            # Recommendation score
            # -------------------------------------------------

            capacity_ratio = (
                available
                / slot_capacity
            )

            capacity_score = (
                capacity_ratio * 40
            )

            wait_score = max(
                0,
                30
                - min(
                    expected_wait_minutes,
                    30,
                ),
            )

            congestion_score = {
                "Low": 20,
                "Medium": 10,
                "High": 0,
            }.get(
                congestion,
                0,
            )

            distance_score = 0.0

            if distance_km is not None:
                distance_score = max(
                    0,
                    10
                    - min(
                        distance_km,
                        10,
                    ),
                )

            recommendation_score = round(
                capacity_score
                + wait_score
                + congestion_score
                + distance_score,
                2,
            )

            recommendations.append(
                {
                    "centre_id": centre.id,

                    "centre_name": getattr(
                        centre,
                        "name",
                        f"Centre {centre.id}",
                    ),

                    "slot_id": slot_id,

                    "slot_start": start,

                    "slot_end": end,

                    "capacity": slot_capacity,

                    "booked": existing_count,

                    "available": available,

                    "expected_wait_minutes":
                        expected_wait_minutes,

                    "congestion_level":
                        congestion,

                    "distance_km":
                        distance_km,

                    "recommendation_score":
                        recommendation_score,
                }
            )

    # -----------------------------------------------------
    # Sort recommendations
    # -----------------------------------------------------

    recommendations.sort(
        key=lambda item: (
            -item[
                "recommendation_score"
            ],

            item[
                "expected_wait_minutes"
            ],

            -item["available"],
        )
    )

    # Return top 5
    return recommendations[:5]


# =========================================================
# EXISTING SMARTPROCURE AI SERVICE
# =========================================================

class SmartProcureAIService:

    def recommend_slots(
        self,
        db,
        booking_date: date,
        crop: str,
        quantity_kg: float,
        latitude: float | None = None,
        longitude: float | None = None,
    ):
        return recommend_smart_slots(
            db=db,
            booking_date=booking_date,
            crop=crop,
            quantity_kg=quantity_kg,
            latitude=latitude,
            longitude=longitude,
        )


ai_service = SmartProcureAIService()