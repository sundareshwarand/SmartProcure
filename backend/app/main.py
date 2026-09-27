from .core import create_app
from .api import health

app = create_app()


@app.get("/api/v1/health", tags=["health"])
async def health_root():
    return await health.ping()
