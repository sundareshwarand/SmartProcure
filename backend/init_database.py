from app.database import Base, engine

# Import all models so SQLAlchemy knows about them
from app.models import (
    User,
    Centre,
    Booking,
    QueueEntry,
    Procurement,
    Payment,
    Notification,
    Grievance,
    AuditLog,
)


print("Creating SmartProcure database tables...")

Base.metadata.create_all(bind=engine)

print("All database tables created successfully!")