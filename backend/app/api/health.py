from fastapi import APIRouter

router = APIRouter(
    prefix="/api/v1/health",
    tags=["Health"],
)

@router.get("")
def health():
    return {
        "success": True,
        "status": "healthy",
        "service": "SmartProcure API",
    }
