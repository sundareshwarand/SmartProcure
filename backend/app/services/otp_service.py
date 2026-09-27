import hashlib
import os
import secrets
import time
from dataclasses import dataclass
from threading import Lock


@dataclass
class OTPRecord:
    verification_id: str
    phone: str
    otp_hash: str
    expires_at: float
    attempts: int
    last_sent_at: float
    verified: bool = False


class OTPService:
    def __init__(self):
        self._records: dict[str, OTPRecord] = {}
        self._lock = Lock()

        self.expiry_seconds = int(
            os.getenv("OTP_EXPIRY_SECONDS", "300")
        )

        self.max_attempts = int(
            os.getenv("OTP_MAX_ATTEMPTS", "5")
        )

        self.resend_seconds = int(
            os.getenv("OTP_RESEND_SECONDS", "30")
        )

        self.length = int(
            os.getenv("OTP_LENGTH", "6")
        )

        self.dev_mode = (
            os.getenv("OTP_DEV_MODE", "true").lower()
            == "true"
        )

    @staticmethod
    def _hash(value: str) -> str:
        return hashlib.sha256(
            value.encode("utf-8")
        ).hexdigest()

    def _generate_otp(self) -> str:
        minimum = 10 ** (self.length - 1)
        maximum = (10 ** self.length) - 1

        return str(
            secrets.randbelow(
                maximum - minimum + 1
            ) + minimum
        )

    def create_verification(
        self,
        phone: str,
    ) -> dict:

        now = time.time()

        with self._lock:
            for record in self._records.values():
                if (
                    record.phone == phone
                    and not record.verified
                    and now - record.last_sent_at
                    < self.resend_seconds
                ):
                    remaining = int(
                        self.resend_seconds
                        - (now - record.last_sent_at)
                    )

                    raise ValueError(
                        f"Please wait {remaining} seconds "
                        "before requesting another OTP."
                    )

            otp = self._generate_otp()

            verification_id = secrets.token_urlsafe(32)

            record = OTPRecord(
                verification_id=verification_id,
                phone=phone,
                otp_hash=self._hash(otp),
                expires_at=now + self.expiry_seconds,
                attempts=0,
                last_sent_at=now,
            )

            self._records[verification_id] = record

        # Never log OTP in production.
        if self.dev_mode:
            print(
                f"[DEV OTP] verification_id={verification_id}"
                f" otp={otp}"
            )

        return {
            "verification_id": verification_id,
            "expires_in": self.expiry_seconds,
            "dev_otp": otp if self.dev_mode else None,
        }

    def verify(
        self,
        verification_id: str,
        otp: str,
    ) -> bool:

        now = time.time()

        with self._lock:
            record = self._records.get(
                verification_id
            )

            if record is None:
                raise ValueError(
                    "Invalid verification request."
                )

            if record.verified:
                raise ValueError(
                    "OTP has already been used."
                )

            if now > record.expires_at:
                del self._records[verification_id]

                raise ValueError(
                    "OTP has expired."
                )

            if record.attempts >= self.max_attempts:
                del self._records[verification_id]

                raise ValueError(
                    "Maximum OTP attempts exceeded."
                )

            record.attempts += 1

            if self._hash(otp) != record.otp_hash:
                raise ValueError(
                    "Invalid OTP."
                )

            record.verified = True

            return True

    def cleanup(self):
        now = time.time()

        with self._lock:
            expired = [
                key
                for key, record in self._records.items()
                if now > record.expires_at
            ]

            for key in expired:
                del self._records[key]


otp_service = OTPService()