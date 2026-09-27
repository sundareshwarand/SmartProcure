from datetime import date, datetime

from app.database import SessionLocal

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


def seed_database():
    db = SessionLocal()

    try:
        # ---------------------------------------------------------
        # 1. CENTRES
        # ---------------------------------------------------------

        centres = [
            Centre(
                code="CTR001",
                name="Kancheepuram Procurement Centre",
                district="Kancheepuram",
                state="Tamil Nadu",
                address="Kancheepuram Main Procurement Road",
                latitude=12.8342,
                longitude=79.7036,
                daily_capacity=150,
                active_counters=3,
                average_processing_minutes=7.5,
                opening_time="09:00",
                closing_time="17:00",
                status="Operational",
                is_active=True,
            ),
            Centre(
                code="CTR002",
                name="Sriperumbudur Procurement Centre",
                district="Kancheepuram",
                state="Tamil Nadu",
                address="Sriperumbudur Agricultural Market",
                latitude=12.9675,
                longitude=79.9414,
                daily_capacity=120,
                active_counters=3,
                average_processing_minutes=6.5,
                opening_time="09:00",
                closing_time="17:00",
                status="Operational",
                is_active=True,
            ),
            Centre(
                code="CTR003",
                name="Walajabad Procurement Centre",
                district="Kancheepuram",
                state="Tamil Nadu",
                address="Walajabad Main Road",
                latitude=12.7900,
                longitude=79.8250,
                daily_capacity=100,
                active_counters=2,
                average_processing_minutes=8.0,
                opening_time="09:00",
                closing_time="17:00",
                status="Operational",
                is_active=True,
            ),
            Centre(
                code="CTR004",
                name="Uthiramerur Procurement Centre",
                district="Kancheepuram",
                state="Tamil Nadu",
                address="Uthiramerur Agricultural Centre",
                latitude=12.6140,
                longitude=79.7570,
                daily_capacity=130,
                active_counters=2,
                average_processing_minutes=9.0,
                opening_time="09:00",
                closing_time="17:00",
                status="Busy",
                is_active=True,
            ),
        ]

        db.add_all(centres)
        db.flush()

        print("✓ Centres created")

        # ---------------------------------------------------------
        # 2. USERS
        # ---------------------------------------------------------

        farmer = User(
            full_name="Suresh Kumar",
            mobile="9876543210",
            username="farmer01",
            password_hash="demo",
            role="farmer",
            village="Kancheepuram",
            district="Kancheepuram",
            state="Tamil Nadu",
            language="English",
            is_active=True,
        )

        operator = User(
            full_name="Procurement Operator",
            mobile="9876543211",
            username="operator01",
            password_hash="demo",
            role="operator",
            village=None,
            district="Kancheepuram",
            state="Tamil Nadu",
            language="English",
            centre_id=centres[0].id,
            is_active=True,
        )

        officer = User(
            full_name="District Procurement Officer",
            mobile="9876543212",
            username="officer01",
            password_hash="demo",
            role="officer",
            district="Kancheepuram",
            state="Tamil Nadu",
            language="English",
            is_active=True,
        )

        admin = User(
            full_name="System Administrator",
            mobile="9876543213",
            username="admin01",
            password_hash="demo",
            role="admin",
            district="Kancheepuram",
            state="Tamil Nadu",
            language="English",
            is_active=True,
        )

        db.add_all([
            farmer,
            operator,
            officer,
            admin,
        ])

        db.flush()

        print("✓ Users created")

        # ---------------------------------------------------------
        # 3. BOOKINGS
        # ---------------------------------------------------------

        booking1 = Booking(
            booking_code="BK202600124",
            farmer_id=farmer.id,
            centre_id=centres[0].id,
            crop="Paddy",
            quantity_kg=1250,
            booking_date=date.today(),
            slot_start="10:30",
            slot_end="11:00",
            token="SP-042",
            queue_position=5,
            estimated_wait_minutes=35,
            status="Checked In",
        )

        booking2 = Booking(
            booking_code="BK202600125",
            farmer_id=farmer.id,
            centre_id=centres[1].id,
            crop="Paddy",
            quantity_kg=900,
            booking_date=date.today(),
            slot_start="12:00",
            slot_end="12:30",
            token="SP-043",
            queue_position=12,
            estimated_wait_minutes=70,
            status="Booked",
        )

        booking3 = Booking(
            booking_code="BK202600126",
            farmer_id=farmer.id,
            centre_id=centres[2].id,
            crop="Paddy",
            quantity_kg=700,
            booking_date=date.today(),
            slot_start="14:00",
            slot_end="14:30",
            token="SP-044",
            queue_position=8,
            estimated_wait_minutes=45,
            status="Booked",
        )

        booking4 = Booking(
            booking_code="BK202600127",
            farmer_id=farmer.id,
            centre_id=centres[0].id,
            crop="Paddy",
            quantity_kg=1000,
            booking_date=date.today(),
            slot_start="09:30",
            slot_end="10:00",
            token="SP-041",
            queue_position=None,
            estimated_wait_minutes=0,
            status="Completed",
        )

        db.add_all([
            booking1,
            booking2,
            booking3,
            booking4,
        ])

        db.flush()

        print("✓ Bookings created")

        # ---------------------------------------------------------
        # 4. QUEUE
        # ---------------------------------------------------------

        queue_entries = [
            QueueEntry(
                booking_id=booking1.id,
                farmer_id=farmer.id,
                centre_id=centres[0].id,
                token="SP-042",
                position=5,
                status="Waiting",
            ),
            QueueEntry(
                booking_id=booking2.id,
                farmer_id=farmer.id,
                centre_id=centres[1].id,
                token="SP-043",
                position=12,
                status="Waiting",
            ),
            QueueEntry(
                booking_id=booking3.id,
                farmer_id=farmer.id,
                centre_id=centres[2].id,
                token="SP-044",
                position=8,
                status="Waiting",
            ),
        ]

        db.add_all(queue_entries)

        print("✓ Queue entries created")

        # ---------------------------------------------------------
        # 5. PROCUREMENT
        # ---------------------------------------------------------

        procurement = Procurement(
            procurement_code="PROC-2026-00841",
            booking_id=booking1.id,
            farmer_id=farmer.id,
            centre_id=centres[0].id,
            crop="Paddy",
            quantity_kg=1250,
            rate_per_kg=23.0,
            gross_amount=28750.0,
            quality_grade="A",
            status="In Progress",
        )

        db.add(procurement)
        db.flush()

        print("✓ Procurement created")

        # ---------------------------------------------------------
        # 6. PAYMENT
        # ---------------------------------------------------------

        payment = Payment(
            procurement_id=procurement.id,
            farmer_id=farmer.id,
            amount=28750.0,
            method="Bank Transfer",
            status="Processing",
            transaction_reference=None,
            initiated_at=datetime.now(),
            paid_at=None,
        )

        db.add(payment)

        print("✓ Payment created")

        # ---------------------------------------------------------
        # 7. NOTIFICATIONS
        # ---------------------------------------------------------

        notifications = [
            Notification(
                farmer_id=farmer.id,
                title="Booking Confirmed",
                message="Your procurement booking BK202600124 is confirmed.",
                notification_type="Booking",
                is_read=False,
            ),
            Notification(
                farmer_id=farmer.id,
                title="Queue Update",
                message="Your current queue position is 5.",
                notification_type="Queue",
                is_read=False,
            ),
            Notification(
                farmer_id=farmer.id,
                title="Payment Processing",
                message="Your payment of ₹28,750 is being processed.",
                notification_type="Payment",
                is_read=False,
            ),
        ]

        db.add_all(notifications)

        print("✓ Notifications created")

        # ---------------------------------------------------------
        # 8. GRIEVANCE
        # ---------------------------------------------------------

        grievance = Grievance(
            grievance_code="GRV-2026-0042",
            farmer_id=farmer.id,
            category="Procurement Delay",
            description="Procurement processing is taking longer than expected.",
            status="Open",
            resolution=None,
        )

        db.add(grievance)

        print("✓ Grievance created")

        # ---------------------------------------------------------
        # 9. AUDIT LOG
        # ---------------------------------------------------------

        audit = AuditLog(
            actor_id=operator.id,
            actor_role="operator",
            centre_id=centres[0].id,
            action="START_PROCESSING",
            target_type="Booking",
            target_id=str(booking1.id),
            success=True,
            failure_reason=None,
            metadata_json={
                "token": "SP-042",
                "booking_code": "BK202600124",
            },
        )

        db.add(audit)

        print("✓ Audit log created")

        # ---------------------------------------------------------
        # COMMIT
        # ---------------------------------------------------------

        db.commit()

        print()
        print("=" * 55)
        print("SmartProcure database seeded successfully!")
        print("=" * 55)
        print()
        print("Demo users:")
        print("Farmer   : farmer01")
        print("Operator : operator01")
        print("Officer  : officer01")
        print("Admin    : admin01")
        print()
        print("Centres  :", len(centres))
        print("Bookings : 4")
        print("Queue    : 3")
        print("Payment  : ₹28,750")
        print()

    except Exception as error:
        db.rollback()

        print()
        print("Database seeding failed!")
        print(error)

    finally:
        db.close()


if __name__ == "__main__":
    seed_database()