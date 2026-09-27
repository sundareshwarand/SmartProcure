from datetime import datetime
import asyncio
import json
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.queue import QueueEntry


router = APIRouter(
    prefix="/api/v1/queue",
    tags=["Queue"],
)


# ---------------------------------------------------------
# WebSocket connection manager
# ---------------------------------------------------------

class QueueConnectionManager:
    def __init__(self):
        self.connections: dict[int, list[WebSocket]] = {}

    async def connect(self, centre_id: int, websocket: WebSocket):
        await websocket.accept()

        if centre_id not in self.connections:
            self.connections[centre_id] = []

        self.connections[centre_id].append(websocket)

    def disconnect(self, centre_id: int, websocket: WebSocket):
        if centre_id in self.connections:
            if websocket in self.connections[centre_id]:
                self.connections[centre_id].remove(websocket)

            if not self.connections[centre_id]:
                del self.connections[centre_id]

    async def broadcast(self, centre_id: int, payload: dict):
        sockets = list(self.connections.get(centre_id, []))

        if not sockets:
            return

        message = json.dumps(payload)

        dead = []

        for websocket in sockets:
            try:
                await websocket.send_text(message)
            except Exception:
                dead.append(websocket)

        for websocket in dead:
            self.disconnect(centre_id, websocket)


manager = QueueConnectionManager()


# ---------------------------------------------------------
# Helpers
# ---------------------------------------------------------

VALID_STATUSES = {
    "Waiting",
    "Called",
    "Processing",
    "Completed",
    "No Show",
}


def serialize_queue(row: QueueEntry):
    return {
        "id": row.id,
        "booking_id": row.booking_id,
        "farmer_id": row.farmer_id,
        "centre_id": row.centre_id,
        "token": row.token,
        "position": row.position,
        "status": row.status,
        "checked_in_at": (
            row.checked_in_at.isoformat()
            if row.checked_in_at
            else None
        ),
        "called_at": (
            row.called_at.isoformat()
            if row.called_at
            else None
        ),
        "processing_started_at": (
            row.processing_started_at.isoformat()
            if row.processing_started_at
            else None
        ),
        "completed_at": (
            row.completed_at.isoformat()
            if row.completed_at
            else None
        ),
        "no_show_at": (
            row.no_show_at.isoformat()
            if getattr(row, "no_show_at", None)
            else None
        ),
        "created_at": (
            row.created_at.isoformat()
            if row.created_at
            else None
        ),
    }


def get_queue_rows(db: Session, centre_id: int):
    return (
        db.query(QueueEntry)
        .filter(QueueEntry.centre_id == centre_id)
        .order_by(QueueEntry.position.asc(), QueueEntry.id.asc())
        .all()
    )


# ---------------------------------------------------------
# GET queue
# ---------------------------------------------------------

@router.get("")
def get_queue(
    centre_id: int,
    db: Session = Depends(get_db),
):
    rows = get_queue_rows(db, centre_id)

    queue = [serialize_queue(row) for row in rows]

    return {
        "success": True,
        "count": len(queue),
        "queue": queue,
    }


# ---------------------------------------------------------
# GET single queue entry
# ---------------------------------------------------------

@router.get("/{queue_id}")
def get_queue_entry(
    queue_id: int,
    db: Session = Depends(get_db),
):
    row = (
        db.query(QueueEntry)
        .filter(QueueEntry.id == queue_id)
        .first()
    )

    if not row:
        raise HTTPException(
            status_code=404,
            detail="Queue entry not found",
        )

    return {
        "success": True,
        "queue": serialize_queue(row),
    }


# ---------------------------------------------------------
# UPDATE queue status
#
# Supports:
# PATCH /api/v1/queue/1/status?status=Called
# PATCH /api/v1/queue/1/status?status=Processing
# PATCH /api/v1/queue/1/status?status=Completed
# PATCH /api/v1/queue/1/status?status=No%20Show
# ---------------------------------------------------------

@router.patch("/{queue_id}/status")
async def update_queue_status(
    queue_id: int,
    status: str = Query(...),
    db: Session = Depends(get_db),
):
    status = status.strip()

    if status not in VALID_STATUSES:
        raise HTTPException(
            status_code=400,
            detail={
                "message": "Invalid queue status",
                "allowed_statuses": sorted(VALID_STATUSES),
            },
        )

    row = (
        db.query(QueueEntry)
        .filter(QueueEntry.id == queue_id)
        .first()
    )

    if not row:
        raise HTTPException(
            status_code=404,
            detail="Queue entry not found",
        )

    previous_status = row.status
    now = datetime.utcnow()

    # -----------------------------------------------------
    # Status transitions
    # -----------------------------------------------------

    if status == "Called":
        if row.status not in {"Waiting", "Called"}:
            raise HTTPException(
                status_code=409,
                detail=f"Cannot call farmer from status '{row.status}'",
            )

        row.status = "Called"
        row.called_at = now

    elif status == "Processing":
        if row.status not in {"Called", "Processing"}:
            raise HTTPException(
                status_code=409,
                detail=f"Cannot start processing from status '{row.status}'",
            )

        row.status = "Processing"
        row.processing_started_at = now

    elif status == "Completed":
        if row.status not in {"Processing", "Completed"}:
            raise HTTPException(
                status_code=409,
                detail=f"Cannot complete from status '{row.status}'",
            )

        row.status = "Completed"
        row.completed_at = now

    elif status == "No Show":
        if row.status not in {"Waiting", "Called", "No Show"}:
            raise HTTPException(
                status_code=409,
                detail=f"Cannot mark no-show from status '{row.status}'",
            )

        row.status = "No Show"

        if hasattr(row, "no_show_at"):
            row.no_show_at = now

    elif status == "Waiting":
        row.status = "Waiting"

        if hasattr(row, "called_at"):
            row.called_at = None

        if hasattr(row, "processing_started_at"):
            row.processing_started_at = None

        if hasattr(row, "completed_at"):
            row.completed_at = None

        if hasattr(row, "no_show_at"):
            row.no_show_at = None

    db.commit()
    db.refresh(row)

    result = serialize_queue(row)

    await manager.broadcast(
        row.centre_id,
        {
            "event": "queue_updated",
            "action": "status_changed",
            "previous_status": previous_status,
            "queue": result,
        },
    )

    return {
        "success": True,
        "message": f"Queue status changed to {status}",
        "previous_status": previous_status,
        "status": row.status,
        "queue": result,
    }


# ---------------------------------------------------------
# Convenience endpoint: CALL NEXT
# ---------------------------------------------------------

@router.post("/call-next")
async def call_next(
    centre_id: int,
    db: Session = Depends(get_db),
):
    row = (
        db.query(QueueEntry)
        .filter(
            QueueEntry.centre_id == centre_id,
            QueueEntry.status == "Waiting",
        )
        .order_by(
            QueueEntry.position.asc(),
            QueueEntry.id.asc(),
        )
        .first()
    )

    if not row:
        return {
            "success": False,
            "message": "No waiting farmers in queue",
            "queue": None,
        }

    previous_status = row.status
    row.status = "Called"
    row.called_at = datetime.utcnow()

    db.commit()
    db.refresh(row)

    result = serialize_queue(row)

    await manager.broadcast(
        centre_id,
        {
            "event": "queue_updated",
            "action": "call_next",
            "previous_status": previous_status,
            "queue": result,
        },
    )

    return {
        "success": True,
        "message": f"Farmer {row.token} called",
        "queue": result,
    }


# ---------------------------------------------------------
# Convenience endpoint: NO SHOW
# ---------------------------------------------------------

@router.post("/{queue_id}/no-show")
async def mark_no_show(
    queue_id: int,
    db: Session = Depends(get_db),
):
    row = (
        db.query(QueueEntry)
        .filter(QueueEntry.id == queue_id)
        .first()
    )

    if not row:
        raise HTTPException(
            status_code=404,
            detail="Queue entry not found",
        )

    if row.status not in {"Waiting", "Called"}:
        raise HTTPException(
            status_code=409,
            detail=f"Cannot mark '{row.status}' farmer as no-show",
        )

    previous_status = row.status
    row.status = "No Show"

    if hasattr(row, "no_show_at"):
        row.no_show_at = datetime.utcnow()

    db.commit()
    db.refresh(row)

    result = serialize_queue(row)

    await manager.broadcast(
        row.centre_id,
        {
            "event": "queue_updated",
            "action": "no_show",
            "previous_status": previous_status,
            "queue": result,
        },
    )

    return {
        "success": True,
        "message": f"Farmer {row.token} marked as No Show",
        "queue": result,
    }


# ---------------------------------------------------------
# WebSocket live queue
# ---------------------------------------------------------

@router.websocket("/ws")
async def queue_websocket(
    websocket: WebSocket,
    centre_id: int,
):
    await manager.connect(centre_id, websocket)

    try:
        await websocket.send_text(
            json.dumps(
                {
                    "event": "connected",
                    "centre_id": centre_id,
                    "message": "Live queue connection established",
                }
            )
        )

        while True:
            try:
                data = await asyncio.wait_for(
                    websocket.receive_text(),
                    timeout=30,
                )

                if data.lower() == "ping":
                    await websocket.send_text(
                        json.dumps(
                            {
                                "event": "pong",
                                "centre_id": centre_id,
                            }
                        )
                    )

            except asyncio.TimeoutError:
                await websocket.send_text(
                    json.dumps(
                        {
                            "event": "heartbeat",
                            "centre_id": centre_id,
                        }
                    )
                )

    except WebSocketDisconnect:
        manager.disconnect(centre_id, websocket)

    except Exception:
        manager.disconnect(centre_id, websocket)
