from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.booking import Booking
from app.models.centre import Centre


router = APIRouter(
    prefix="/api/v1/bookings",
    tags=["Bookings"],
)


# =========================================================
# HELPERS
# =========================================================

def _centre_name(centre):
    """
    Supports either `name` or `centre_name`
    depending on the Centre model.
    """
    name = getattr(centre, "name", None)

    if name:
        return str(name)

    name = getattr(centre, "centre_name", None)

    if name:
        return str(name)

    return "Procurement Centre"


def _booking_response(booking, centre=None):
    return {
        "id": booking.id,
        "booking_code": booking.booking_code,
        "farmer_id": booking.farmer_id,
        "centre_id": booking.centre_id,
        "crop": booking.crop,
        "quantity_kg": booking.quantity_kg,
        "booking_date": str(booking.booking_date),
        "slot_start": booking.slot_start,
        "slot_end": booking.slot_end,
        "token": booking.token,
        "queue_position": booking.queue_position,
        "estimated_wait_minutes": booking.estimated_wait_minutes,
        "status": booking.status,
        "centre_name": (
            _centre_name(centre)
            if centre is not None
            else None
        ),
    }


# =========================================================
# GET ALL BOOKINGS
# =========================================================

@router.get("")
def get_bookings(
    farmer_id: int | None = None,
    centre_id: int | None = None,
    db: Session = Depends(get_db),
):
    query = db.query(Booking)

    if farmer_id is not None:
        query = query.filter(
            Booking.farmer_id == farmer_id
        )

    if centre_id is not None:
        query = query.filter(
            Booking.centre_id == centre_id
        )

    bookings = (
        query
        .order_by(Booking.booking_date.desc())
        .all()
    )

    result = []

    for booking in bookings:
        centre = (
            db.query(Centre)
            .filter(Centre.id == booking.centre_id)
            .first()
        )

        result.append(
            _booking_response(
                booking,
                centre,
            )
        )

    return {
        "success": True,
        "count": len(result),
        "bookings": result,
    }


# =========================================================
# GET SINGLE BOOKING
# =========================================================

@router.get("/{booking_id}")
def get_booking(
    booking_id: int,
    db: Session = Depends(get_db),
):
    booking = (
        db.query(Booking)
        .filter(Booking.id == booking_id)
        .first()
    )

    if not booking:
        raise HTTPException(
            status_code=404,
            detail="Booking not found",
        )

    centre = (
        db.query(Centre)
        .filter(Centre.id == booking.centre_id)
        .first()
    )

    return {
        "success": True,
        "booking": _booking_response(
            booking,
            centre,
        ),
    }


# =========================================================
# CREATE BOOKING
# =========================================================

@router.post("")
def create_booking(
    farmer_id: int,
    centre_id: int,
    crop: str,
    quantity_kg: float,
    booking_date: date,
    slot_start: str,
    slot_end: str,
    db: Session = Depends(get_db),
):
    try:

        # -------------------------------------------------
        # BASIC VALIDATION
        # -------------------------------------------------

        if quantity_kg <= 0:
            raise HTTPException(
                status_code=400,
                detail="Quantity must be greater than zero",
            )

        if not crop or not crop.strip():
            raise HTTPException(
                status_code=400,
                detail="Crop is required",
            )

        if not slot_start or not slot_end:
            raise HTTPException(
                status_code=400,
                detail="Slot start and end time are required",
            )

        # -------------------------------------------------
        # VALID SLOT
        # -------------------------------------------------

        valid_slots = {
            ("09:00", "10:00"),
            ("10:00", "11:00"),
            ("11:00", "12:00"),
            ("14:00", "15:00"),
            ("15:00", "16:00"),
        }

        if (slot_start, slot_end) not in valid_slots:
            raise HTTPException(
                status_code=400,
                detail="Invalid procurement time slot",
            )

        # -------------------------------------------------
        # CHECK CENTRE
        # -------------------------------------------------

        centre = (
            db.query(Centre)
            .filter(Centre.id == centre_id)
            .first()
        )

        if not centre:
            raise HTTPException(
                status_code=404,
                detail="Centre not found",
            )

        # -------------------------------------------------
        # CENTRE CAPACITY
        # -------------------------------------------------

        daily_capacity = getattr(
            centre,
            "capacity",
            None,
        )

        if daily_capacity is None:
            daily_capacity = 100

        daily_capacity = int(daily_capacity)

        number_of_slots = 5

        slot_capacity = max(
            1,
            daily_capacity // number_of_slots,
        )

        # -------------------------------------------------
        # EXISTING BOOKINGS
        # -------------------------------------------------

        active_statuses = [
            "Cancelled",
            "No Show",
        ]

        existing_count = (
            db.query(Booking)
            .filter(
                Booking.centre_id == centre_id,
                Booking.booking_date == booking_date,
                Booking.slot_start == slot_start,
                Booking.slot_end == slot_end,
                Booking.status.notin_(
                    active_statuses
                ),
            )
            .count()
        )

        # -------------------------------------------------
        # PREVENT OVERBOOKING
        # -------------------------------------------------

        if existing_count >= slot_capacity:
            raise HTTPException(
                status_code=409,
                detail=(
                    "Selected slot is full. "
                    "Please choose another available slot."
                ),
            )

        # -------------------------------------------------
        # DUPLICATE FARMER BOOKING
        # -------------------------------------------------

        duplicate_booking = (
            db.query(Booking)
            .filter(
                Booking.farmer_id == farmer_id,
                Booking.centre_id == centre_id,
                Booking.booking_date == booking_date,
                Booking.slot_start == slot_start,
                Booking.slot_end == slot_end,
                Booking.status.notin_(
                    active_statuses
                ),
            )
            .first()
        )

        if duplicate_booking:
            raise HTTPException(
                status_code=409,
                detail=(
                    "You already have a booking "
                    "for this centre, date and slot."
                ),
            )

        # -------------------------------------------------
        # BOOKING CODE
        # -------------------------------------------------

        total_bookings = (
            db.query(Booking).count()
        )

        booking_code = (
            f"BK2026{total_bookings + 1:05d}"
        )

        # -------------------------------------------------
        # TOKEN
        # -------------------------------------------------

        token_number = 40 + total_bookings + 1

        token = f"SP-{token_number:03d}"

        # -------------------------------------------------
        # QUEUE POSITION
        # -------------------------------------------------

        queue_position = (
            existing_count + 1
        )

        # -------------------------------------------------
        # PROCESSING TIME
        # -------------------------------------------------

        average_processing_time = getattr(
            centre,
            "average_processing_time",
            None,
        )

        if average_processing_time is None:
            average_processing_time = 7.0

        average_processing_time = float(
            average_processing_time
        )

        estimated_wait_minutes = int(
            max(
                0,
                (
                    queue_position - 1
                )
                * average_processing_time,
            )
        )

        # -------------------------------------------------
        # CREATE BOOKING
        # -------------------------------------------------

        booking = Booking(
            booking_code=booking_code,
            farmer_id=farmer_id,
            centre_id=centre_id,
            crop=crop.strip(),
            quantity_kg=quantity_kg,
            booking_date=booking_date,
            slot_start=slot_start,
            slot_end=slot_end,
            token=token,
            queue_position=queue_position,
            estimated_wait_minutes=(
                estimated_wait_minutes
            ),
            status="Booked",
        )

        db.add(booking)

        # -------------------------------------------------
        # SAVE
        # -------------------------------------------------

        db.commit()
        db.refresh(booking)

        # -------------------------------------------------
        # SUCCESS RESPONSE
        # -------------------------------------------------

        return {
            "success": True,
            "message": "Booking created successfully",
            "booking": _booking_response(
                booking,
                centre,
            ),
        }

    except HTTPException:
        db.rollback()
        raise

    except Exception as exc:
        db.rollback()

        print(
            "BOOKING CREATE ERROR:",
            repr(exc),
        )

        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to create booking. "
                "Please try again."
            ),
        )


# =========================================================
# CANCEL BOOKING
# =========================================================

@router.patch("/{booking_id}/cancel")
def cancel_booking(
    booking_id: int,
    db: Session = Depends(get_db),
):
    booking = (
        db.query(Booking)
        .filter(Booking.id == booking_id)
        .first()
    )

    if not booking:
        raise HTTPException(
            status_code=404,
            detail="Booking not found",
        )

    if booking.status in [
        "Completed",
        "Cancelled",
        "Processing",
    ]:
        raise HTTPException(
            status_code=409,
            detail="Booking cannot be cancelled",
        )

    booking.status = "Cancelled"

    db.commit()
    db.refresh(booking)

    return {
        "success": True,
        "message": "Booking cancelled successfully",
        "booking": {
            "id": booking.id,
            "booking_code": booking.booking_code,
            "status": booking.status,
        },
    }