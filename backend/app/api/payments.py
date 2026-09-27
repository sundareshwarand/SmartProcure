from datetime import datetime
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.payment import Payment
from app.models.procurement import Procurement


router = APIRouter(
    prefix="/api/v1/payments",
    tags=["Payments"],
)


VALID_STATUSES = {
    "Pending",
    "Processing",
    "Paid",
    "Failed",
    "Cancelled",
}


TRANSITIONS = {
    "Pending": {
        "Processing",
        "Cancelled",
    },
    "Processing": {
        "Paid",
        "Failed",
    },
    "Failed": {
        "Processing",
        "Cancelled",
    },
    "Paid": set(),
    "Cancelled": set(),
}


def _money(value):
    if value is None:
        return 0.0

    return round(float(value), 2)


def _dt(value):
    return str(value) if value else None


def _payment_dict(payment):
    return {
        "id": payment.id,
        "procurement_id": payment.procurement_id,
        "farmer_id": payment.farmer_id,
        "amount": _money(payment.amount),
        "method": payment.method,
        "status": payment.status,
        "transaction_reference":
            payment.transaction_reference,
        "initiated_at":
            _dt(payment.initiated_at),
        "paid_at":
            _dt(payment.paid_at),
        "created_at":
            _dt(payment.created_at),
    }


def _get_payment(
    payment_id: int,
    db: Session,
    lock: bool = False,
):

    query = (
        db.query(Payment)
        .filter(
            Payment.id == payment_id
        )
    )

    if lock:
        query = query.with_for_update()

    payment = query.first()

    if not payment:
        raise HTTPException(
            status_code=404,
            detail="Payment not found",
        )

    return payment


# ============================================================
# LIST PAYMENTS
# ============================================================

@router.get("")
def get_payments(
    farmer_id: int | None = None,
    procurement_id: int | None = None,
    status: str | None = None,
    db: Session = Depends(get_db),
):

    query = db.query(Payment)

    if farmer_id is not None:
        query = query.filter(
            Payment.farmer_id == farmer_id
        )

    if procurement_id is not None:
        query = query.filter(
            Payment.procurement_id
            == procurement_id
        )

    if status:
        query = query.filter(
            Payment.status == status
        )

    payments = (
        query
        .order_by(
            Payment.id.desc()
        )
        .all()
    )

    total_amount = sum(
        _money(p.amount)
        for p in payments
    )

    paid_amount = sum(
        _money(p.amount)
        for p in payments
        if p.status == "Paid"
    )

    processing_amount = sum(
        _money(p.amount)
        for p in payments
        if p.status == "Processing"
    )

    failed_amount = sum(
        _money(p.amount)
        for p in payments
        if p.status == "Failed"
    )

    return {
        "success": True,
        "count": len(payments),

        "summary": {
            "total_amount": total_amount,
            "paid_amount": paid_amount,
            "processing_amount":
                processing_amount,
            "failed_amount":
                failed_amount,
        },

        "payments": [
            _payment_dict(p)
            for p in payments
        ],
    }


# ============================================================
# SINGLE PAYMENT
# ============================================================

@router.get("/{payment_id}")
def get_payment(
    payment_id: int,
    db: Session = Depends(get_db),
):

    payment = _get_payment(
        payment_id,
        db,
    )

    return {
        "success": True,
        "payment":
            _payment_dict(payment),
    }


# ============================================================
# START PAYMENT PROCESSING
# ============================================================

@router.post("/{payment_id}/process")
def process_payment(
    payment_id: int,
    db: Session = Depends(get_db),
):

    payment = _get_payment(
        payment_id,
        db,
        lock=True,
    )

    if payment.status == "Paid":
        return {
            "success": True,
            "message":
                "Payment is already completed",
            "payment":
                _payment_dict(payment),
        }

    if payment.status not in {
        "Pending",
        "Failed",
    }:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Payment cannot be processed "
                f"from status {payment.status}"
            ),
        )

    procurement = (
        db.query(Procurement)
        .filter(
            Procurement.id
            == payment.procurement_id
        )
        .first()
    )

    if not procurement:
        raise HTTPException(
            status_code=409,
            detail=(
                "Associated procurement "
                "does not exist"
            ),
        )

    if procurement.status != "Completed":
        raise HTTPException(
            status_code=409,
            detail=(
                "Procurement must be completed "
                "before payment processing"
            ),
        )

    if payment.amount <= 0:
        raise HTTPException(
            status_code=409,
            detail=(
                "Payment amount must be "
                "greater than zero"
            ),
        )

    payment.status = "Processing"

    if payment.initiated_at is None:
        payment.initiated_at = (
            datetime.utcnow()
        )

    db.commit()
    db.refresh(payment)

    return {
        "success": True,
        "message":
            "Payment processing started",
        "payment":
            _payment_dict(payment),
    }


# ============================================================
# MARK PAYMENT PAID
# ============================================================

@router.post("/{payment_id}/complete")
def complete_payment(
    payment_id: int,
    transaction_reference: str | None = None,
    db: Session = Depends(get_db),
):

    payment = _get_payment(
        payment_id,
        db,
        lock=True,
    )

    if payment.status == "Paid":
        return {
            "success": True,
            "message":
                "Payment already completed",
            "payment":
                _payment_dict(payment),
        }

    if payment.status != "Processing":
        raise HTTPException(
            status_code=409,
            detail=(
                "Only Processing payments "
                "can be completed"
            ),
        )

    reference = (
        transaction_reference.strip()
        if transaction_reference
        else ""
    )

    if not reference:
        reference = (
            "SPTX-"
            + datetime.utcnow().strftime(
                "%Y%m%d%H%M%S"
            )
            + "-"
            + uuid4().hex[:8].upper()
        )

    duplicate = (
        db.query(Payment)
        .filter(
            Payment.transaction_reference
            == reference,
            Payment.id != payment.id,
        )
        .first()
    )

    if duplicate:
        raise HTTPException(
            status_code=409,
            detail=(
                "Transaction reference "
                "already exists"
            ),
        )

    payment.status = "Paid"
    payment.transaction_reference = reference
    payment.paid_at = datetime.utcnow()

    db.commit()
    db.refresh(payment)

    return {
        "success": True,
        "message":
            "Payment completed successfully",
        "payment":
            _payment_dict(payment),
    }


# ============================================================
# PAYMENT FAILED
# ============================================================

@router.post("/{payment_id}/fail")
def fail_payment(
    payment_id: int,
    reason: str = "Bank transaction failed",
    db: Session = Depends(get_db),
):

    payment = _get_payment(
        payment_id,
        db,
        lock=True,
    )

    if payment.status == "Paid":
        raise HTTPException(
            status_code=409,
            detail=(
                "A completed payment "
                "cannot be failed"
            ),
        )

    if payment.status != "Processing":
        raise HTTPException(
            status_code=409,
            detail=(
                "Only Processing payments "
                "can be marked Failed"
            ),
        )

    payment.status = "Failed"

    db.commit()
    db.refresh(payment)

    return {
        "success": True,
        "message":
            "Payment marked as failed",
        "reason":
            reason.strip(),
        "payment":
            _payment_dict(payment),
    }


# ============================================================
# RETRY FAILED PAYMENT
# ============================================================

@router.post("/{payment_id}/retry")
def retry_payment(
    payment_id: int,
    db: Session = Depends(get_db),
):

    payment = _get_payment(
        payment_id,
        db,
        lock=True,
    )

    if payment.status != "Failed":
        raise HTTPException(
            status_code=409,
            detail=(
                "Only Failed payments "
                "can be retried"
            ),
        )

    payment.status = "Processing"
    payment.initiated_at = datetime.utcnow()

    db.commit()
    db.refresh(payment)

    return {
        "success": True,
        "message":
            "Payment retry initiated",
        "payment":
            _payment_dict(payment),
    }


# ============================================================
# CANCEL PAYMENT
# ============================================================

@router.post("/{payment_id}/cancel")
def cancel_payment(
    payment_id: int,
    db: Session = Depends(get_db),
):

    payment = _get_payment(
        payment_id,
        db,
        lock=True,
    )

    if payment.status not in {
        "Pending",
        "Failed",
    }:
        raise HTTPException(
            status_code=409,
            detail=(
                "Only Pending or Failed "
                "payments can be cancelled"
            ),
        )

    payment.status = "Cancelled"

    db.commit()
    db.refresh(payment)

    return {
        "success": True,
        "message":
            "Payment cancelled",
        "payment":
            _payment_dict(payment),
    }


# ============================================================
# GENERIC STATUS ENDPOINT
# ============================================================

@router.patch("/{payment_id}/status")
def update_payment_status(
    payment_id: int,
    status: str,
    db: Session = Depends(get_db),
):

    payment = _get_payment(
        payment_id,
        db,
        lock=True,
    )

    status = status.strip()

    if status not in VALID_STATUSES:
        raise HTTPException(
            status_code=400,
            detail=(
                "Invalid payment status"
            ),
        )

    current = payment.status

    if current == status:
        return {
            "success": True,
            "message":
                "Payment already has this status",
            "payment":
                _payment_dict(payment),
        }

    allowed = TRANSITIONS.get(
        current,
        set(),
    )

    if status not in allowed:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Invalid payment transition: "
                f"{current} → {status}"
            ),
        )

    if status == "Paid":

        reference = (
            "SPTX-"
            + datetime.utcnow().strftime(
                "%Y%m%d%H%M%S"
            )
            + "-"
            + uuid4().hex[:8].upper()
        )

        payment.transaction_reference = (
            reference
        )

        payment.paid_at = datetime.utcnow()

    if status == "Processing":
        payment.initiated_at = (
            payment.initiated_at
            or datetime.utcnow()
        )

    payment.status = status

    db.commit()
    db.refresh(payment)

    return {
        "success": True,
        "previous_status": current,
        "status": payment.status,
        "payment":
            _payment_dict(payment),
    }