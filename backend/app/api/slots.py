from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.booking import Booking
from app.models.centre import Centre


router = APIRouter(
    prefix="/api/v1/slots",
    tags=["Slots"],
)


SLOT_WINDOWS = [
    ("09:00", "10:00"),
    ("10:00", "11:00"),
    ("11:00", "12:00"),
    ("14:00", "15:00"),
    ("15:00", "16:00"),
]


@router.get("")
def get_available_slots(
    centre_id: int,
    booking_date: date,
    db: Session = Depends(get_db),
):
    """
    Return real slot availability for a procurement centre and date.

    Capacity is divided across the configured time slots.
    Cancelled and No Show bookings do not consume slot capacity.
    """

    try:
        # ---------------------------------------------------------
        # Find centre
        # ---------------------------------------------------------
        centre = (
            db.query(Centre)
            .filter(Centre.id == centre_id)
            .first()
        )

        if centre is None:
            raise HTTPException(
                status_code=404,
                detail="Procurement centre not found.",
            )

        # ---------------------------------------------------------
        # Centre capacity
        # ---------------------------------------------------------
        daily_capacity = int(
            getattr(centre, "capacity", 100) or 100
        )

        slot_capacity = max(
            1,
            daily_capacity // len(SLOT_WINDOWS),
        )

        slots = []

        # ---------------------------------------------------------
        # Calculate every slot
        # ---------------------------------------------------------
        for slot_id, (start, end) in enumerate(
            SLOT_WINDOWS,
            start=1,
        ):
            query = (
                db.query(Booking)
                .filter(
                    Booking.centre_id == centre_id,
                    Booking.booking_date == booking_date,
                    Booking.slot_start == start,
                    Booking.slot_end == end,
                )
            )

            bookings = query.all()

            # Cancelled and No Show bookings should
            # not consume capacity.
            active_bookings = [
                booking
                for booking in bookings
                if str(
                    getattr(booking, "status", "")
                ).strip().lower()
                not in {
                    "cancelled",
                    "no show",
                    "no_show",
                }
            ]

            booked = len(active_bookings)

            available = max(
                0,
                slot_capacity - booked,
            )

            slots.append(
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

        # ---------------------------------------------------------
        # Response
        # ---------------------------------------------------------
        return {
            "success": True,
            "centre_id": centre_id,
            "booking_date": str(booking_date),
            "daily_capacity": daily_capacity,
            "slot_capacity": slot_capacity,
            "slots": slots,
        }

    except HTTPException:
        raise

    except Exception as exc:
        # Keep the actual backend error visible in Swagger
        # instead of returning an unexplained 500.
        print("SLOT API ERROR:", repr(exc))

        raise HTTPException(
            status_code=500,
            detail=f"Unable to calculate slot availability: {exc}",
        )