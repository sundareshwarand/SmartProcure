from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.auth import router as auth_router
from app.api.health import router as health_router
from app.api.ai import router as ai_router
from app.api.centres import router as centres_router
from app.api.bookings import router as bookings_router
from app.api.queue import router as queue_router
from app.api.procurement import router as procurement_router
from app.api.payments import router as payments_router
from app.api.notifications import router as notifications_router
from app.api.grievances import router as grievances_router
from app.api.audit import router as audit_router
from app.api.officer import router as officer_router
from app.api.admin import router as admin_router
from app.api.slots import router as slots_router
from app.api.ai_dashboard import router as ai_dashboard_router
from app.api.operator import router as operator_router
app = FastAPI(
    title="Smart Digital Procurement API",
    description=(
        "SmartProcure - Intelligent Farmer Procurement "
        "and Queue Management System"
    ),
    version="1.0.0",
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(auth_router)
app.include_router(health_router)
app.include_router(ai_router)
app.include_router(centres_router)
app.include_router(bookings_router)
app.include_router(queue_router)
app.include_router(procurement_router)
app.include_router(payments_router)
app.include_router(notifications_router)
app.include_router(grievances_router)
app.include_router(audit_router)
app.include_router(officer_router)
app.include_router(admin_router)
app.include_router(slots_router)
app.include_router(ai_dashboard_router)
app.include_router(operator_router)
@app.get("/")
def root():
    return {
        "message": "Smart Digital Procurement API is running",
        "service": "SmartProcure",
        "version": "1.0.0",
        "status": "online",
    }


@app.get("/health")
def backend_health():
    return {
        "status": "healthy",
        "service": "SmartProcure Backend",
    }
from app.api import otp

app.include_router(otp.router)

from app.api.otp import router as otp_router

app.include_router(otp_router)




from app.api.otp import router as otp_router
app.include_router(otp_router)

