from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.audit import AuditLog

router = APIRouter(
    prefix="/api/v1/audit",
    tags=["Audit"],
)


@router.get("")
def get_audit_logs(
    centre_id: int | None = None,
    db: Session = Depends(get_db),
):
    query = db.query(AuditLog)

    if centre_id:
        query = query.filter(AuditLog.centre_id == centre_id)

    logs = (
        query
        .order_by(AuditLog.id.desc())
        .limit(100)
        .all()
    )

    return {
        "success": True,
        "count": len(logs),
        "logs": [
            {
                "id": a.id,
                "actor_id": a.actor_id,
                "actor_role": a.actor_role,
                "centre_id": a.centre_id,
                "action": a.action,
                "target_type": a.target_type,
                "target_id": a.target_id,
                "success": a.success,
                "failure_reason": a.failure_reason,
                "metadata": a.metadata_json,
                "created_at": str(a.created_at),
            }
            for a in logs
        ],
    }