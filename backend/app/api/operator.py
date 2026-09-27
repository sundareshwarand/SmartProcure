from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.booking import Booking
from app.models.centre import Centre


router = APIRouter(
    prefix="/api/v1/operator",
    tags=["Centre Operator"],
)


ACTIVE_STATUSES = {
    "waiting",
    "called",
    "processing",
    "checked in",
    "checked_in",
}


def _safe_int(value, default=0):
    try:
        return int(value or default)
    except Exception:
        return default


def _safe_float(value, default=0.0):
    try:
        return float(value or default)
    except Exception:
        return default


def _status(value):
    return str(
        value or ""
    ).strip().lower()


def _centre_or_404(
    db: Session,
    centre_id: int,
):
    centre = (
        db.query(Centre)
        .filter(
            Centre.id == centre_id,
        )
        .first()
    )

    if centre is None:
        raise HTTPException(
            status_code=404,
            detail="Procurement centre not found.",
        )

    return centre


def _booking_value(
    booking,
    name,
    default=None,
):
    return getattr(
        booking,
        name,
        default,
    )


def _queue_position(
    db: Session,
    booking,
):
    booking_date = _booking_value(
        booking,
        "booking_date",
    )

    centre_id = _booking_value(
        booking,
        "centre_id",
    )

    if booking_date is None:
        return 0

    bookings = (
        db.query(Booking)
        .filter(
            Booking.centre_id == centre_id,
            Booking.booking_date == booking_date,
        )
        .all()
    )

    active = []

    for item in bookings:
        current = _status(
            _booking_value(
                item,
                "status",
            )
        )

        if current in {
            "cancelled",
            "no show",
            "no_show",
            "completed",
        }:
            continue

        active.append(item)

    active.sort(
        key=lambda item: (
            str(
                _booking_value(
                    item,
                    "slot_start",
                    "",
                )
            ),
            _safe_int(
                _booking_value(
                    item,
                    "id",
                    0,
                )
            ),
        )
    )

    for index, item in enumerate(
        active,
        start=1,
    ):
        if (
            _safe_int(
                _booking_value(
                    item,
                    "id",
                    0,
                )
            )
            ==
            _safe_int(
                _booking_value(
                    booking,
                    "id",
                    0,
                )
            )
        ):
            return index

    return 0


def _booking_payload(
    db: Session,
    booking,
    centre,
):
    quantity = _safe_float(
        _booking_value(
            booking,
            "quantity_kg",
            0,
        )
    )

    status = str(
        _booking_value(
            booking,
            "status",
            "Waiting",
        )
        or "Waiting"
    )

    processing_time = _safe_float(
        getattr(
            centre,
            "average_processing_time",
            7,
        ),
        7,
    )

    position = _queue_position(
        db,
        booking,
    )

    return {
        "id": _safe_int(
            _booking_value(
                booking,
                "id",
                0,
            )
        ),
        "booking_id": _safe_int(
            _booking_value(
                booking,
                "id",
                0,
            )
        ),
        "farmer_id": _safe_int(
            _booking_value(
                booking,
                "farmer_id",
                0,
            )
        ),
        "centre_id": _safe_int(
            _booking_value(
                booking,
                "centre_id",
                0,
            )
        ),
        "farmer_name": (
            f"Farmer "
            f"{_safe_int(_booking_value(booking, 'farmer_id', 0))}"
        ),
        "token": str(
            _booking_value(
                booking,
                "token",
                "---",
            )
            or "---"
        ),
        "crop": str(
            _booking_value(
                booking,
                "crop",
                "Paddy",
            )
            or "Paddy"
        ),
        "quantity_kg": quantity,
        "booking_date": str(
            _booking_value(
                booking,
                "booking_date",
                "",
            )
        ),
        "slot_start": str(
            _booking_value(
                booking,
                "slot_start",
                "",
            )
            or ""
        ),
        "slot_end": str(
            _booking_value(
                booking,
                "slot_end",
                "",
            )
            or ""
        ),
        "status": status,
        "queue_position": position,
        "estimated_wait_minutes": int(
            max(
                0,
                (position - 1)
                * processing_time,
            )
        ),
    }


# =============================================================================
# OVERVIEW
# =============================================================================


@router.get("/overview")
def operator_overview(
    centre_id: int,
    db: Session = Depends(get_db),
):
    centre = _centre_or_404(
        db,
        centre_id,
    )

    today = date.today()

    bookings = (
        db.query(Booking)
        .filter(
            Booking.centre_id == centre_id,
            Booking.booking_date == today,
        )
        .all()
    )

    waiting = 0
    called = 0
    processing = 0
    completed = 0
    no_show = 0

    total_quantity = 0.0
    completed_quantity = 0.0

    for booking in bookings:
        status = _status(
            _booking_value(
                booking,
                "status",
            )
        )

        quantity = _safe_float(
            _booking_value(
                booking,
                "quantity_kg",
                0,
            )
        )

        total_quantity += quantity

        if status in {
            "waiting",
            "checked in",
            "checked_in",
        }:
            waiting += 1

        elif status == "called":
            called += 1

        elif status == "processing":
            processing += 1

        elif status == "completed":
            completed += 1
            completed_quantity += quantity

        elif status in {
            "no show",
            "no_show",
        }:
            no_show += 1

    capacity = _safe_int(
        getattr(
            centre,
            "capacity",
            0,
        ),
        0,
    )

    active_count = (
        waiting +
        called +
        processing
    )

    utilization = 0.0

    if capacity > 0:
        utilization = (
            active_count / capacity
        ) * 100

    return {
        "success": True,
        "date": str(today),
        "centre": {
            "id": centre_id,
            "name": str(
                getattr(
                    centre,
                    "name",
                    f"Centre {centre_id}",
                )
            ),
            "capacity": capacity,
            "counters": _safe_int(
                getattr(
                    centre,
                    "counters",
                    1,
                ),
                1,
            ),
            "average_processing_time":
                _safe_float(
                    getattr(
                        centre,
                        "average_processing_time",
                        7,
                    ),
                    7,
                ),
        },
        "queue": {
            "waiting": waiting,
            "called": called,
            "processing": processing,
            "active": active_count,
        },
        "today": {
            "total_bookings": len(
                bookings
            ),
            "completed_bookings":
                completed,
            "no_show_bookings":
                no_show,
            "total_quantity_kg":
                total_quantity,
            "completed_quantity_kg":
                completed_quantity,
        },
        "utilization": {
            "percentage":
                round(
                    utilization,
                    2,
                ),
            "status": (
                "High load"
                if utilization >= 80
                else "Moderate load"
                if utilization >= 50
                else "Normal operations"
            ),
        },
    }


# =============================================================================
# CENTRE
# =============================================================================


@router.get("/centre")
def operator_centre(
    centre_id: int,
    db: Session = Depends(get_db),
):
    centre = _centre_or_404(
        db,
        centre_id,
    )

    today = date.today()

    bookings = (
        db.query(Booking)
        .filter(
            Booking.centre_id == centre_id,
            Booking.booking_date == today,
        )
        .all()
    )

    active = 0

    for booking in bookings:
        status = _status(
            _booking_value(
                booking,
                "status",
            )
        )

        if status in ACTIVE_STATUSES:
            active += 1

    capacity = _safe_int(
        getattr(
            centre,
            "capacity",
            0,
        ),
        0,
    )

    utilization = 0

    if capacity > 0:
        utilization = (
            active / capacity
        ) * 100

    return {
        "success": True,
        "centre": {
            "id": centre_id,
            "name": str(
                getattr(
                    centre,
                    "name",
                    f"Centre {centre_id}",
                )
            ),
            "capacity": capacity,
            "counters": _safe_int(
                getattr(
                    centre,
                    "counters",
                    1,
                ),
                1,
            ),
            "average_processing_time":
                _safe_float(
                    getattr(
                        centre,
                        "average_processing_time",
                        7,
                    ),
                    7,
                ),
            "queue_paused": False,
        },
        "active_farmers": active,
        "utilization_percentage":
            round(
                utilization,
                2,
            ),
    }


# =============================================================================
# QUEUE
# =============================================================================


@router.get("/queue")
def operator_queue(
    centre_id: int,
    db: Session = Depends(get_db),
):
    centre = _centre_or_404(
        db,
        centre_id,
    )

    today = date.today()

    bookings = (
        db.query(Booking)
        .filter(
            Booking.centre_id == centre_id,
            Booking.booking_date == today,
        )
        .all()
    )

    active = []

    for booking in bookings:
        status = _status(
            _booking_value(
                booking,
                "status",
            )
        )

        if status in {
            "cancelled",
            "completed",
            "no show",
            "no_show",
        }:
            continue

        active.append(
            _booking_payload(
                db,
                booking,
                centre,
            )
        )

    active.sort(
        key=lambda item: (
            item["queue_position"],
            item["id"],
        )
    )

    return {
        "success": True,
        "date": str(today),
        "count": len(active),
        "queue": active,
    }


# =============================================================================
# QUEUE PAUSE / RESUME
# =============================================================================


@router.post("/queue/pause")
def pause_queue(
    centre_id: int,
    reason: str = "",
    db: Session = Depends(get_db),
):
    _centre_or_404(
        db,
        centre_id,
    )

    return {
        "success": True,
        "centre_id": centre_id,
        "queue_paused": True,
        "reason": reason,
        "message":
            "Queue pause request accepted.",
    }


@router.post("/queue/resume")
def resume_queue(
    centre_id: int,
    db: Session = Depends(get_db),
):
    _centre_or_404(
        db,
        centre_id,
    )

    return {
        "success": True,
        "centre_id": centre_id,
        "queue_paused": False,
        "message":
            "Queue resumed successfully.",
    }