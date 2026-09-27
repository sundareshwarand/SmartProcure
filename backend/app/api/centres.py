from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.booking import Booking
from app.models.centre import Centre


router = APIRouter(
    prefix="/api/v1/centres",
    tags=["Procurement Centres"],
)


ACTIVE_BOOKING_STATUSES = {
    "booked",
    "checked in",
    "checked_in",
    "waiting",
    "called",
    "processing",
    "in progress",
}


CLOSED_BOOKING_STATUSES = {
    "cancelled",
    "canceled",
    "no show",
    "no_show",
}


SLOT_WINDOWS = [
    ("09:00", "10:00"),
    ("10:00", "11:00"),
    ("11:00", "12:00"),
    ("14:00", "15:00"),
    ("15:00", "16:00"),
]


def _normalise_status(value):
    return str(value or "").strip().lower()


def _safe_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _safe_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _centre_name(centre):
    return str(
        getattr(
            centre,
            "name",
            None,
        )
        or f"Procurement Centre #{centre.id}"
    )


def _centre_code(centre):
    return str(
        getattr(
            centre,
            "code",
            None,
        )
        or f"CTR{centre.id:03d}"
    )


def _centre_capacity(centre):
    return max(
        1,
        _safe_int(
            getattr(
                centre,
                "capacity",
                100,
            ),
            100,
        ),
    )


def _centre_counters(centre):
    return max(
        1,
        _safe_int(
            getattr(
                centre,
                "counters",
                1,
            ),
            1,
        ),
    )


def _processing_time(centre):
    return max(
        1.0,
        _safe_float(
            getattr(
                centre,
                "average_processing_time",
                7.0,
            ),
            7.0,
        ),
    )


def _location(centre):
    value = getattr(
        centre,
        "location",
        None,
    )

    if value:
        return str(value)

    address = getattr(
        centre,
        "address",
        None,
    )

    if address:
        return str(address)

    return "Procurement Centre"


def _coordinates(centre):
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

    return (
        _safe_float(latitude, 0.0)
        if latitude is not None
        else None,
        _safe_float(longitude, 0.0)
        if longitude is not None
        else None,
    )


def _analyse_centre(
    centre,
    bookings,
    target_date,
):
    capacity = _centre_capacity(centre)
    counters = _centre_counters(centre)
    processing_time = _processing_time(centre)

    centre_bookings = [
        booking
        for booking in bookings
        if getattr(
            booking,
            "centre_id",
            None,
        )
        == centre.id
    ]

    today_bookings = [
        booking
        for booking in centre_bookings
        if getattr(
            booking,
            "booking_date",
            None,
        )
        == target_date
    ]

    active_today = [
        booking
        for booking in today_bookings
        if _normalise_status(
            getattr(
                booking,
                "status",
                None,
            )
        )
        not in CLOSED_BOOKING_STATUSES
    ]

    queue_bookings = [
        booking
        for booking in active_today
        if _normalise_status(
            getattr(
                booking,
                "status",
                None,
            )
        )
        in {
            "checked in",
            "checked_in",
            "waiting",
            "called",
            "processing",
            "in progress",
        }
    ]

    completed_today = [
        booking
        for booking in today_bookings
        if _normalise_status(
            getattr(
                booking,
                "status",
                None,
            )
        )
        == "completed"
    ]

    waiting_count = len(
        [
            booking
            for booking in queue_bookings
            if _normalise_status(
                getattr(
                    booking,
                    "status",
                    None,
                )
            )
            in {
                "waiting",
                "checked in",
                "checked_in",
            }
        ]
    )

    called_count = len(
        [
            booking
            for booking in queue_bookings
            if _normalise_status(
                getattr(
                    booking,
                    "status",
                    None,
                )
            )
            == "called"
        ]
    )

    processing_count = len(
        [
            booking
            for booking in queue_bookings
            if _normalise_status(
                getattr(
                    booking,
                    "status",
                    None,
                )
            )
            in {
                "processing",
                "in progress",
            }
        ]
    )

    booked_count = len(active_today)

    available_capacity = max(
        0,
        capacity - booked_count,
    )

    utilization = min(
        100.0,
        (
            booked_count / capacity
        )
        * 100,
    )

    estimated_wait = round(
        (
            waiting_count
            * processing_time
        )
        / counters
    )

    if utilization >= 80:
        congestion = "High"
    elif utilization >= 50:
        congestion = "Medium"
    else:
        congestion = "Low"

    if processing_count >= counters:
        operational_status = "Busy"
    elif utilization >= 90:
        operational_status = "Near Capacity"
    else:
        operational_status = "Operational"

    slot_data = []

    for slot_id, (start, end) in enumerate(
        SLOT_WINDOWS,
        start=1,
    ):
        slot_bookings = [
            booking
            for booking in today_bookings
            if str(
                getattr(
                    booking,
                    "slot_start",
                    "",
                )
            )
            == start
            and str(
                getattr(
                    booking,
                    "slot_end",
                    "",
                )
            )
            == end
        ]

        active_slot_bookings = [
            booking
            for booking in slot_bookings
            if _normalise_status(
                getattr(
                    booking,
                    "status",
                    None,
                )
            )
            not in CLOSED_BOOKING_STATUSES
        ]

        slot_capacity = max(
            1,
            capacity // len(SLOT_WINDOWS),
        )

        booked = len(
            active_slot_bookings
        )

        available = max(
            0,
            slot_capacity - booked,
        )

        slot_data.append(
            {
                "slot_id": slot_id,
                "start": start,
                "end": end,
                "label": f"{start} - {end}",
                "capacity": slot_capacity,
                "booked": booked,
                "available": available,
                "is_available": available > 0,
            }
        )

    latitude, longitude = _coordinates(
        centre
    )

    return {
        "id": centre.id,
        "centre_id": centre.id,
        "name": _centre_name(centre),
        "code": _centre_code(centre),
        "location": _location(centre),
        "capacity": capacity,
        "counters": counters,
        "average_processing_time": processing_time,
        "status": operational_status,
        "operational_status": operational_status,
        "queue_length": len(queue_bookings),
        "current_queue": len(queue_bookings),
        "waiting": waiting_count,
        "called": called_count,
        "processing": processing_count,
        "completed_today": len(completed_today),
        "today_bookings": booked_count,
        "available_capacity": available_capacity,
        "utilization": round(
            utilization,
            1,
        ),
        "utilization_percentage": round(
            utilization,
            1,
        ),
        "estimated_wait_minutes": estimated_wait,
        "congestion": congestion,
        "congestion_level": congestion,
        "latitude": latitude,
        "longitude": longitude,
        "slots": slot_data,
        "updated_at": None,
    }


@router.get("")
def get_centres(
    db: Session = Depends(get_db),
):
    """
    Return all procurement centres with
    real-time operational calculations.
    """

    centres = (
        db.query(Centre)
        .order_by(
            Centre.id.asc()
        )
        .all()
    )

    bookings = (
        db.query(Booking)
        .all()
    )

    today = date.today()

    result = [
        _analyse_centre(
            centre=centre,
            bookings=bookings,
            target_date=today,
        )
        for centre in centres
    ]

    return {
        "success": True,
        "date": str(today),
        "count": len(result),
        "centres": result,
    }


@router.get("/{centre_id}")
def get_centre(
    centre_id: int,
    db: Session = Depends(get_db),
):
    """
    Return complete real-time information
    for one procurement centre.
    """

    centre = (
        db.query(Centre)
        .filter(
            Centre.id == centre_id
        )
        .first()
    )

    if centre is None:
        raise HTTPException(
            status_code=404,
            detail="Procurement centre not found.",
        )

    bookings = (
        db.query(Booking)
        .all()
    )

    result = _analyse_centre(
        centre=centre,
        bookings=bookings,
        target_date=date.today(),
    )

    return {
        "success": True,
        "centre": result,
    }