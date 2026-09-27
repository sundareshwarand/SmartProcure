from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.procurement import Procurement
from app.models.payment import Payment


router = APIRouter(
    prefix="/api/v1/procurement",
    tags=["Procurement"],
)


# ============================================================
# CONSTANTS
# ============================================================

VALID_STATUSES = {
    "In Progress",
    "Quality Checking",
    "Weighing",
    "Amount Calculated",
    "Completed",
}

QUALITY_GRADES = {
    "A",
    "B",
    "C",
}

STATUS_TRANSITIONS = {
    "In Progress": [
        "Quality Checking",
    ],
    "Quality Checking": [
        "Weighing",
    ],
    "Weighing": [
        "Amount Calculated",
    ],
    "Amount Calculated": [
        "Completed",
    ],
    "Completed": [],
}


# ============================================================
# HELPERS
# ============================================================

def _money(value):
    if value is None:
        return 0.0

    return float(
        Decimal(str(value)).quantize(
            Decimal("0.01"),
            rounding=ROUND_HALF_UP,
        )
    )


def _number(value):
    if value is None:
        return 0.0

    try:
        return float(value)
    except Exception:
        return 0.0


def _datetime(value):
    if value is None:
        return None

    return str(value)


def _get_procurement(
    procurement_id: int,
    db: Session,
    lock: bool = False,
):
    query = (
        db.query(Procurement)
        .filter(
            Procurement.id == procurement_id
        )
    )

    if lock:
        query = query.with_for_update()

    procurement = query.first()

    if not procurement:
        raise HTTPException(
            status_code=404,
            detail="Procurement not found",
        )

    return procurement


def _extra_data(
    procurement_id: int,
    db: Session,
):
    """
    Advanced fields are stored in the MySQL
    procurements table while the original SQLAlchemy
    model remains backward compatible.
    """

    result = db.execute(
        text(
            """
            SELECT
                actual_weight_kg,
                moisture_percentage,
                foreign_matter_percentage,
                damaged_percentage,
                quality_remarks,
                quality_passed,
                deductions,
                net_payable,
                weighing_completed_at,
                quality_checked_at,
                amount_calculated_at
            FROM procurements
            WHERE id = :procurement_id
            """
        ),
        {
            "procurement_id": procurement_id,
        },
    ).mappings().first()

    if not result:
        return {
            "actual_weight_kg": None,
            "moisture_percentage": None,
            "foreign_matter_percentage": None,
            "damaged_percentage": None,
            "quality_remarks": None,
            "quality_passed": None,
            "deductions": 0,
            "net_payable": None,
            "weighing_completed_at": None,
            "quality_checked_at": None,
            "amount_calculated_at": None,
        }

    return dict(result)


def _procurement_dict(
    procurement: Procurement,
    db: Session,
):
    extra = _extra_data(
        procurement.id,
        db,
    )

    booked_weight = _number(
        procurement.quantity_kg
    )

    actual_weight = (
        _number(extra["actual_weight_kg"])
        if extra["actual_weight_kg"] is not None
        else None
    )

    difference = (
        actual_weight - booked_weight
        if actual_weight is not None
        else None
    )

    variance = (
        (difference / booked_weight) * 100
        if (
            difference is not None
            and booked_weight > 0
        )
        else None
    )

    return {
        "id": procurement.id,
        "procurement_code":
            procurement.procurement_code,

        "booking_id":
            procurement.booking_id,

        "farmer_id":
            procurement.farmer_id,

        "centre_id":
            procurement.centre_id,

        "crop":
            procurement.crop,

        "quantity_kg":
            procurement.quantity_kg,

        "rate_per_kg":
            procurement.rate_per_kg,

        "gross_amount":
            _money(procurement.gross_amount),

        "quality_grade":
            procurement.quality_grade,

        "status":
            procurement.status,

        "actual_weight_kg":
            actual_weight,

        "weight_difference_kg":
            difference,

        "weight_variance_percentage":
            variance,

        "moisture_percentage":
            extra["moisture_percentage"],

        "foreign_matter_percentage":
            extra["foreign_matter_percentage"],

        "damaged_percentage":
            extra["damaged_percentage"],

        "quality_remarks":
            extra["quality_remarks"],

        "quality_passed":
            extra["quality_passed"],

        "deductions":
            _money(extra["deductions"]),

        "net_payable":
            (
                _money(extra["net_payable"])
                if extra["net_payable"] is not None
                else None
            ),

        "quality_checked_at":
            _datetime(
                extra["quality_checked_at"]
            ),

        "weighing_completed_at":
            _datetime(
                extra["weighing_completed_at"]
            ),

        "amount_calculated_at":
            _datetime(
                extra["amount_calculated_at"]
            ),

        "completed_at":
            _datetime(
                procurement.completed_at
            ),

        "created_at":
            _datetime(
                procurement.created_at
            ),
    }


def _validate_transition(
    current_status,
    new_status,
):
    if new_status not in VALID_STATUSES:
        raise HTTPException(
            status_code=400,
            detail=(
                "Invalid procurement status. "
                "Allowed statuses: "
                "In Progress, Quality Checking, "
                "Weighing, Amount Calculated, Completed"
            ),
        )

    if current_status == new_status:
        return

    allowed = STATUS_TRANSITIONS.get(
        current_status,
        [],
    )

    if new_status not in allowed:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Invalid transition: "
                f"{current_status} → {new_status}"
            ),
        )


# ============================================================
# GET ALL PROCUREMENT
# ============================================================

@router.get("")
def get_procurements(
    farmer_id: int | None = None,
    centre_id: int | None = None,
    status: str | None = None,
    db: Session = Depends(get_db),
):
    query = db.query(Procurement)

    if farmer_id is not None:
        query = query.filter(
            Procurement.farmer_id == farmer_id
        )

    if centre_id is not None:
        query = query.filter(
            Procurement.centre_id == centre_id
        )

    if status:
        query = query.filter(
            Procurement.status == status
        )

    items = (
        query
        .order_by(
            Procurement.id.desc()
        )
        .all()
    )

    return {
        "success": True,
        "count": len(items),
        "procurements": [
            _procurement_dict(
                item,
                db,
            )
            for item in items
        ],
    }


# ============================================================
# BOOKING → PROCUREMENT
# ============================================================

@router.get("/booking/{booking_id}")
def get_procurement_by_booking(
    booking_id: int,
    db: Session = Depends(get_db),
):
    procurement = (
        db.query(Procurement)
        .filter(
            Procurement.booking_id == booking_id
        )
        .order_by(
            Procurement.id.desc()
        )
        .first()
    )

    if not procurement:
        raise HTTPException(
            status_code=404,
            detail=(
                "Procurement record not found "
                "for this booking"
            ),
        )

    return {
        "success": True,
        "procurement":
            _procurement_dict(
                procurement,
                db,
            ),
    }


# ============================================================
# GET SINGLE PROCUREMENT
# ============================================================

@router.get("/{procurement_id}")
def get_procurement(
    procurement_id: int,
    db: Session = Depends(get_db),
):
    procurement = _get_procurement(
        procurement_id,
        db,
    )

    return {
        "success": True,
        "procurement":
            _procurement_dict(
                procurement,
                db,
            ),
    }


# ============================================================
# QUALITY INSPECTION
# ============================================================

@router.post("/{procurement_id}/quality-check")
def quality_check(
    procurement_id: int,
    quality_grade: str,
    moisture_percentage: float = 0,
    foreign_matter_percentage: float = 0,
    damaged_percentage: float = 0,
    quality_remarks: str = "",
    db: Session = Depends(get_db),
):
    procurement = _get_procurement(
        procurement_id,
        db,
        lock=True,
    )

    if procurement.status != "In Progress":
        raise HTTPException(
            status_code=409,
            detail=(
                "Quality inspection requires "
                "In Progress status"
            ),
        )

    grade = quality_grade.strip().upper()

    if grade not in QUALITY_GRADES:
        raise HTTPException(
            status_code=400,
            detail="Quality grade must be A, B or C",
        )

    if not 0 <= moisture_percentage <= 100:
        raise HTTPException(
            status_code=400,
            detail=(
                "Moisture percentage must "
                "be between 0 and 100"
            ),
        )

    if not 0 <= foreign_matter_percentage <= 100:
        raise HTTPException(
            status_code=400,
            detail=(
                "Foreign matter percentage "
                "must be between 0 and 100"
            ),
        )

    if not 0 <= damaged_percentage <= 100:
        raise HTTPException(
            status_code=400,
            detail=(
                "Damaged percentage must "
                "be between 0 and 100"
            ),
        )

    quality_passed = (
        grade in {"A", "B"}
        and moisture_percentage <= 20
        and foreign_matter_percentage <= 5
        and damaged_percentage <= 5
    )

    now = datetime.utcnow()

    db.execute(
        text(
            """
            UPDATE procurements
            SET
                quality_grade = :quality_grade,
                moisture_percentage = :moisture,
                foreign_matter_percentage = :foreign_matter,
                damaged_percentage = :damaged,
                quality_remarks = :remarks,
                quality_passed = :passed,
                quality_checked_at = :checked_at,
                status = 'Quality Checking'
            WHERE id = :procurement_id
            """
        ),
        {
            "quality_grade": grade,
            "moisture":
                moisture_percentage,
            "foreign_matter":
                foreign_matter_percentage,
            "damaged":
                damaged_percentage,
            "remarks":
                quality_remarks.strip(),
            "passed":
                quality_passed,
            "checked_at":
                now,
            "procurement_id":
                procurement_id,
        },
    )

    db.commit()

    return {
        "success": True,
        "message":
            "Quality inspection completed",

        "quality": {
            "grade": grade,
            "moisture_percentage":
                moisture_percentage,
            "foreign_matter_percentage":
                foreign_matter_percentage,
            "damaged_percentage":
                damaged_percentage,
            "passed":
                quality_passed,
            "remarks":
                quality_remarks.strip(),
        },

        "status":
            "Quality Checking",
    }


# ============================================================
# DIGITAL WEIGHING
# ============================================================

@router.post("/{procurement_id}/weigh")
def complete_weighing(
    procurement_id: int,
    actual_weight_kg: float,
    db: Session = Depends(get_db),
):
    procurement = _get_procurement(
        procurement_id,
        db,
        lock=True,
    )

    if procurement.status != "Quality Checking":
        raise HTTPException(
            status_code=409,
            detail=(
                "Weighing requires "
                "Quality Checking status"
            ),
        )

    if actual_weight_kg <= 0:
        raise HTTPException(
            status_code=400,
            detail=(
                "Actual weight must "
                "be greater than zero"
            ),
        )

    booked_weight = _number(
        procurement.quantity_kg
    )

    difference = (
        actual_weight_kg -
        booked_weight
    )

    variance = (
        difference /
        booked_weight *
        100
        if booked_weight > 0
        else 0
    )

    now = datetime.utcnow()

    db.execute(
        text(
            """
            UPDATE procurements
            SET
                actual_weight_kg = :actual_weight,
                weighing_completed_at = :weighing_time,
                status = 'Weighing'
            WHERE id = :procurement_id
            """
        ),
        {
            "actual_weight":
                actual_weight_kg,

            "weighing_time":
                now,

            "procurement_id":
                procurement_id,
        },
    )

    db.commit()

    return {
        "success": True,
        "message":
            "Digital weighing completed",

        "booked_weight_kg":
            round(booked_weight, 2),

        "actual_weight_kg":
            round(actual_weight_kg, 2),

        "difference_kg":
            round(difference, 2),

        "variance_percentage":
            round(variance, 2),

        "status":
            "Weighing",
    }


# ============================================================
# AMOUNT CALCULATION
# ============================================================

@router.post("/{procurement_id}/calculate-amount")
def calculate_amount(
    procurement_id: int,
    deductions: float = 0,
    db: Session = Depends(get_db),
):
    procurement = _get_procurement(
        procurement_id,
        db,
        lock=True,
    )

    if procurement.status != "Weighing":
        raise HTTPException(
            status_code=409,
            detail=(
                "Amount calculation requires "
                "Weighing status"
            ),
        )

    extra = _extra_data(
        procurement_id,
        db,
    )

    actual_weight = _number(
        extra["actual_weight_kg"]
    )

    rate = _number(
        procurement.rate_per_kg
    )

    if actual_weight <= 0:
        raise HTTPException(
            status_code=409,
            detail="Actual weight is unavailable",
        )

    if rate <= 0:
        raise HTTPException(
            status_code=409,
            detail="Procurement rate is unavailable",
        )

    if deductions < 0:
        raise HTTPException(
            status_code=400,
            detail="Deductions cannot be negative",
        )

    gross_amount = (
        Decimal(str(actual_weight))
        * Decimal(str(rate))
    )

    deduction_amount = Decimal(
        str(deductions)
    )

    if deduction_amount > gross_amount:
        raise HTTPException(
            status_code=400,
            detail=(
                "Deductions cannot exceed "
                "gross amount"
            ),
        )

    net_payable = (
        gross_amount -
        deduction_amount
    )

    gross_amount = gross_amount.quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP,
    )

    net_payable = net_payable.quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP,
    )

    now = datetime.utcnow()

    procurement.gross_amount = float(
        gross_amount
    )

    db.execute(
        text(
            """
            UPDATE procurements
            SET
                deductions = :deductions,
                net_payable = :net_payable,
                amount_calculated_at = :calculated_at,
                status = 'Amount Calculated'
            WHERE id = :procurement_id
            """
        ),
        {
            "deductions":
                float(deduction_amount),

            "net_payable":
                float(net_payable),

            "calculated_at":
                now,

            "procurement_id":
                procurement_id,
        },
    )

    db.commit()

    return {
        "success": True,
        "message":
            "Procurement amount calculated",

        "calculation": {
            "actual_weight_kg":
                round(actual_weight, 2),

            "rate_per_kg":
                round(rate, 2),

            "gross_amount":
                float(gross_amount),

            "deductions":
                float(deduction_amount),

            "net_payable":
                float(net_payable),
        },

        "status":
            "Amount Calculated",
    }


# ============================================================
# COMPLETE PROCUREMENT
# ============================================================

@router.post("/{procurement_id}/complete")
def complete_procurement(
    procurement_id: int,
    db: Session = Depends(get_db),
):
    procurement = _get_procurement(
        procurement_id,
        db,
        lock=True,
    )

    if procurement.status != "Amount Calculated":
        raise HTTPException(
            status_code=409,
            detail=(
                "Procurement completion requires "
                "Amount Calculated status"
            ),
        )

    extra = _extra_data(
        procurement_id,
        db,
    )

    if extra["net_payable"] is None:
        raise HTTPException(
            status_code=409,
            detail="Net payable amount is missing",
        )

    now = datetime.utcnow()

    procurement.status = "Completed"
    procurement.completed_at = now

    db.commit()
    db.refresh(procurement)

    return {
        "success": True,
        "message":
            "Procurement completed successfully",

        "procurement":
            _procurement_dict(
                procurement,
                db,
            ),
    }


# ============================================================
# STATUS UPDATE
# ============================================================

@router.patch("/{procurement_id}/status")
def update_procurement_status(
    procurement_id: int,
    status: str,
    db: Session = Depends(get_db),
):
    procurement = _get_procurement(
        procurement_id,
        db,
        lock=True,
    )

    _validate_transition(
        procurement.status,
        status,
    )

    previous_status = (
        procurement.status
    )

    procurement.status = status

    if status == "Completed":
        procurement.completed_at = (
            datetime.utcnow()
        )

    db.commit()
    db.refresh(procurement)

    return {
        "success": True,
        "message":
            "Procurement status updated",

        "previous_status":
            previous_status,

        "status":
            procurement.status,

        "completed_at":
            _datetime(
                procurement.completed_at
            ),
    }


# ============================================================
# TRIGGER PAYMENT
# ============================================================

@router.post("/{procurement_id}/trigger-payment")
def trigger_payment(
    procurement_id: int,
    db: Session = Depends(get_db),
):
    procurement = _get_procurement(
        procurement_id,
        db,
        lock=True,
    )

    if procurement.status != "Completed":
        raise HTTPException(
            status_code=409,
            detail=(
                "Payment can only be triggered "
                "after procurement completion"
            ),
        )

    extra = _extra_data(
        procurement_id,
        db,
    )

    payment_amount = (
        extra["net_payable"]
        if extra["net_payable"] is not None
        else procurement.gross_amount
    )

    existing_payment = (
        db.query(Payment)
        .filter(
            Payment.procurement_id ==
            procurement.id
        )
        .first()
    )

    if existing_payment:
        return {
            "success": True,
            "message":
                "Payment already exists",

            "payment_id":
                existing_payment.id,

            "payment_status":
                existing_payment.status,
        }

    payment = Payment(
        procurement_id=
            procurement.id,

        farmer_id=
            procurement.farmer_id,

        amount=
            _money(payment_amount),

        method=
            "Bank Transfer",

        status=
            "Processing",

        transaction_reference=
            None,

        initiated_at=
            datetime.utcnow(),
    )

    db.add(payment)
    db.commit()
    db.refresh(payment)

    return {
        "success": True,

        "message":
            "Payment triggered successfully",

        "payment": {
            "id":
                payment.id,

            "procurement_id":
                payment.procurement_id,

            "farmer_id":
                payment.farmer_id,

            "amount":
                _money(payment.amount),

            "method":
                payment.method,

            "status":
                payment.status,

            "transaction_reference":
                payment.transaction_reference,

            "initiated_at":
                _datetime(
                    payment.initiated_at
                ),
        },
    }


# ============================================================
# DIGITAL RECEIPT
# ============================================================

@router.get("/{procurement_id}/receipt")
def get_procurement_receipt(
    procurement_id: int,
    db: Session = Depends(get_db),
):
    procurement = _get_procurement(
        procurement_id,
        db,
    )

    if procurement.status != "Completed":
        raise HTTPException(
            status_code=409,
            detail=(
                "Digital receipt is available "
                "only after completion"
            ),
        )

    extra = _extra_data(
        procurement_id,
        db,
    )

    return {
        "success": True,

        "receipt": {
            "receipt_number":
                procurement.procurement_code,

            "procurement_id":
                procurement.id,

            "procurement_code":
                procurement.procurement_code,

            "booking_id":
                procurement.booking_id,

            "farmer_id":
                procurement.farmer_id,

            "centre_id":
                procurement.centre_id,

            "crop":
                procurement.crop,

            "booked_quantity_kg":
                procurement.quantity_kg,

            "actual_weight_kg":
                extra["actual_weight_kg"],

            "quality_grade":
                procurement.quality_grade,

            "quality_passed":
                extra["quality_passed"],

            "moisture_percentage":
                extra["moisture_percentage"],

            "foreign_matter_percentage":
                extra["foreign_matter_percentage"],

            "damaged_percentage":
                extra["damaged_percentage"],

            "rate_per_kg":
                procurement.rate_per_kg,

            "gross_amount":
                _money(
                    procurement.gross_amount
                ),

            "deductions":
                _money(
                    extra["deductions"]
                ),

            "net_payable":
                (
                    _money(
                        extra["net_payable"]
                    )
                    if extra["net_payable"]
                    is not None
                    else None
                ),

            "status":
                procurement.status,

            "completed_at":
                _datetime(
                    procurement.completed_at
                ),
        },
    }