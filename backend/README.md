# SmartProcure FastAPI backend

Quick start:

1. Create a virtualenv and install requirements:

   python -m venv .venv
   .venv\Scripts\activate
   pip install -r requirements.txt

2. Copy `.env.example` to `.env` and edit values.

3. Run the app:

   python main.py

The API docs will be available at http://127.0.0.1:8000/docs and the OpenAPI JSON at http://127.0.0.1:8000/openapi.json

This is a minimal demo implementation for local development. It does not persist users — replace with database-backed logic for production.
