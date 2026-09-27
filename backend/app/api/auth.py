from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from jose import jwt

router = APIRouter(
    prefix="/api/v1/auth",
    tags=["Authentication"],
)

SECRET_KEY = "smartprocure-development-secret-key"
ALGORITHM = "HS256"


USERS = {
    "farmer01": {
        "username": "farmer01",
        "password": "demo",
        "role": "farmer",
        "centre_ids": [],
    },
    "operator01": {
        "username": "operator01",
        "password": "demo",
        "role": "operator",
        "centre_ids": [1],
    },
    "officer01": {
        "username": "officer01",
        "password": "demo",
        "role": "officer",
        "centre_ids": [],
    },
    "admin01": {
        "username": "admin01",
        "password": "demo",
        "role": "admin",
        "centre_ids": [],
    },
}


class LoginRequest(BaseModel):
    username: str
    password: str
    role: str | None = None
    centre_ids: list[int] = []


def create_token(user: dict):
    now = datetime.now(timezone.utc)

    payload = {
        "sub": user["username"],
        "role": user["role"],
        "centre_ids": user.get("centre_ids", []),
        "iat": now,
        "exp": now + timedelta(minutes=60),
    }

    return jwt.encode(
        payload,
        SECRET_KEY,
        algorithm=ALGORITHM,
    )


@router.post("/login")
def login(request: LoginRequest):
    username = request.username.strip()
    password = request.password

    user = USERS.get(username)

    if not user or user["password"] != password:
        raise HTTPException(
            status_code=401,
            detail="Invalid username or password",
        )

    # Role must match selected login role when supplied.
    if request.role and request.role.lower() != user["role"]:
        raise HTTPException(
            status_code=403,
            detail="Selected role does not match this account",
        )

    token = create_token(user)

    return {
        "success": True,
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "username": user["username"],
            "role": user["role"],
            "centre_ids": user.get("centre_ids", []),
        },
    }


@router.get("/me")
def me(authorization: str | None = None):
    return {
        "success": True,
        "message": "Authentication endpoint available",
    }


@router.post("/logout")
def logout():
    return {
        "success": True,
        "message": "Logged out successfully",
    }
