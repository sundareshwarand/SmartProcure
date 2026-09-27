from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.centre import Centre
from app.models.audit import AuditLog


router = APIRouter(
    prefix="/api/v1/admin",
    tags=["Administrator"],
)


# =============================================================================
# HELPERS
# =============================================================================

def _safe_int(value, default=0):
    try:
        return int(value)
    except Exception:
        return default


def _safe_float(value, default=0.0):
    try:
        return float(value)
    except Exception:
        return default


def _safe_string(value, default="-"):
    if value is None:
        return default

    text = str(value).strip()

    if not text:
        return default

    return text


def _serialize_user(user):
    return {
        "id": user.id,
        "username": _safe_string(
            getattr(user, "username", None)
        ),
        "name": _safe_string(
            getattr(user, "name", None),
            _safe_string(
                getattr(user, "full_name", None),
                "User",
            ),
        ),
        "full_name": _safe_string(
            getattr(user, "full_name", None),
            _safe_string(
                getattr(user, "name", None),
                "User",
            ),
        ),
        "mobile": _safe_string(
            getattr(user, "mobile", None),
            _safe_string(
                getattr(user, "phone", None),
                "-",
            ),
        ),
        "phone": _safe_string(
            getattr(user, "phone", None),
            _safe_string(
                getattr(user, "mobile", None),
                "-",
            ),
        ),
        "role": _safe_string(
            getattr(user, "role", None),
            "farmer",
        ),
        "is_active": bool(
            getattr(user, "is_active", True)
        ),
        "centre_id": getattr(
            user,
            "centre_id",
            None,
        ),
    }


def _serialize_centre(centre):
    return {
        "id": centre.id,
        "name": _safe_string(
            getattr(centre, "name", None),
            "Procurement Centre",
        ),
        "centre_name": _safe_string(
            getattr(centre, "name", None),
            "Procurement Centre",
        ),
        "code": _safe_string(
            getattr(centre, "code", None),
            "-",
        ),
        "centre_code": _safe_string(
            getattr(centre, "code", None),
            "-",
        ),
        "capacity": _safe_int(
            getattr(centre, "capacity", None),
            0,
        ),
        "counters": _safe_int(
            getattr(centre, "counters", None),
            0,
        ),
        "counter_count": _safe_int(
            getattr(centre, "counters", None),
            0,
        ),
        "average_processing_time":
            _safe_float(
                getattr(
                    centre,
                    "average_processing_time",
                    None,
                ),
                0,
            ),
        "avg_processing_time":
            _safe_float(
                getattr(
                    centre,
                    "average_processing_time",
                    None,
                ),
                0,
            ),
        "status": _safe_string(
            getattr(centre, "status", None),
            "Operational",
        ),
    }


def _serialize_audit(audit):
    timestamp = getattr(
        audit,
        "timestamp",
        None,
    )

    if timestamp is None:
        timestamp = getattr(
            audit,
            "created_at",
            None,
        )

    if isinstance(
        timestamp,
        datetime,
    ):
        timestamp = timestamp.isoformat()

    return {
        "id": getattr(
            audit,
            "id",
            None,
        ),
        "actor_id": getattr(
            audit,
            "actor_id",
            None,
        ),
        "actor_role": _safe_string(
            getattr(
                audit,
                "actor_role",
                None,
            ),
            "-",
        ),
        "centre_id": getattr(
            audit,
            "centre_id",
            None,
        ),
        "action": _safe_string(
            getattr(
                audit,
                "action",
                None,
            ),
            "System Action",
        ),
        "target_id": getattr(
            audit,
            "target_id",
            None,
        ),
        "success": bool(
            getattr(
                audit,
                "success",
                True,
            )
        ),
        "timestamp": _safe_string(
            timestamp,
            "-",
        ),
        "created_at": _safe_string(
            timestamp,
            "-",
        ),
    }


# =============================================================================
# ADMIN OVERVIEW
# =============================================================================

@router.get("/overview")
def get_admin_overview(
    db: Session = Depends(get_db),
):
    try:
        total_users = db.query(
            func.count(User.id)
        ).scalar() or 0

        farmers = db.query(
            func.count(User.id)
        ).filter(
            func.lower(User.role) == "farmer"
        ).scalar() or 0

        operators = db.query(
            func.count(User.id)
        ).filter(
            func.lower(User.role) == "operator"
        ).scalar() or 0

        officers = db.query(
            func.count(User.id)
        ).filter(
            func.lower(User.role) == "officer"
        ).scalar() or 0

        admins = db.query(
            func.count(User.id)
        ).filter(
            func.lower(User.role) == "admin"
        ).scalar() or 0

        active_centres = db.query(
            func.count(Centre.id)
        ).scalar() or 0

        system_activity = db.query(
            func.count(AuditLog.id)
        ).scalar() or 0

        return {
            "success": True,
            "overview": {
                "total_users": int(total_users),
                "farmers": int(farmers),
                "operators": int(operators),
                "officers": int(officers),
                "admins": int(admins),
                "active_centres": int(
                    active_centres
                ),
                "system_activity": int(
                    system_activity
                ),
                "backend_status": "Operational",
                "database_status": "Connected",
                "ai_status": "Available",
                "api_status": "Healthy",
            },
        }

    except Exception as exc:
        print(
            "ADMIN OVERVIEW ERROR:",
            repr(exc),
        )

        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to load administrator "
                f"overview: {exc}"
            ),
        )


# =============================================================================
# USERS
# =============================================================================

@router.get("/users")
def get_admin_users(
    search: str | None = Query(
        default=None,
    ),
    role: str | None = Query(
        default=None,
    ),
    db: Session = Depends(get_db),
):
    try:
        query = db.query(User)

        if role:
            query = query.filter(
                func.lower(User.role)
                == role.strip().lower()
            )

        users = query.order_by(
            User.id.desc()
        ).all()

        result = []

        search_text = (
            search.strip().lower()
            if search
            else ""
        )

        for user in users:
            data = _serialize_user(user)

            if search_text:
                searchable = " ".join(
                    [
                        str(
                            data.get(
                                "username",
                                "",
                            )
                        ),
                        str(
                            data.get(
                                "name",
                                "",
                            )
                        ),
                        str(
                            data.get(
                                "mobile",
                                "",
                            )
                        ),
                        str(
                            data.get(
                                "role",
                                "",
                            )
                        ),
                    ]
                ).lower()

                if search_text not in searchable:
                    continue

            result.append(data)

        return {
            "success": True,
            "count": len(result),
            "users": result,
        }

    except Exception as exc:
        print(
            "ADMIN USERS ERROR:",
            repr(exc),
        )

        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to load users: "
                f"{exc}"
            ),
        )


# =============================================================================
# CENTRES
# =============================================================================

@router.get("/centres")
def get_admin_centres(
    db: Session = Depends(get_db),
):
    try:
        centres = db.query(
            Centre
        ).order_by(
            Centre.id.asc()
        ).all()

        result = [
            _serialize_centre(
                centre
            )
            for centre in centres
        ]

        return {
            "success": True,
            "count": len(result),
            "centres": result,
        }

    except Exception as exc:
        print(
            "ADMIN CENTRES ERROR:",
            repr(exc),
        )

        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to load centres: "
                f"{exc}"
            ),
        )


# =============================================================================
# AUDIT
# =============================================================================

@router.get("/audit")
def get_admin_audit_logs(
    limit: int = Query(
        default=100,
        ge=1,
        le=500,
    ),
    db: Session = Depends(get_db),
):
    try:
        logs = db.query(
            AuditLog
        ).order_by(
            AuditLog.id.desc()
        ).limit(
            limit
        ).all()

        result = [
            _serialize_audit(
                audit
            )
            for audit in logs
        ]

        return {
            "success": True,
            "count": len(result),
            "audit": result,
        }

    except Exception as exc:
        print(
            "ADMIN AUDIT ERROR:",
            repr(exc),
        )

        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to load audit logs: "
                f"{exc}"
            ),
        )