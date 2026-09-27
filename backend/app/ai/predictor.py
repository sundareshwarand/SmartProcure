from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, Optional

import joblib
import numpy as np


BASE_DIR = Path(__file__).resolve().parent
MODEL_DIR = BASE_DIR / "models"


class SmartProcurePredictor:

    def __init__(self) -> None:
        self.wait_time_model = self._load(
            "wait_time_model.joblib"
        )

        self.demand_model = self._load(
            "demand_model.joblib"
        )

        self.delay_model = self._load(
            "delay_model.joblib"
        )

    def _load(
        self,
        filename: str,
    ) -> Optional[Any]:

        path = MODEL_DIR / filename

        if not path.exists():
            return None

        try:
            return joblib.load(path)
        except Exception as exc:
            print(
                f"AI model loading failed: "
                f"{filename}: {exc}"
            )
            return None

    def predict_wait_time(
        self,
        waiting_farmers: int,
        processing_capacity: int,
        avg_processing_minutes: float,
        active_counters: int,
    ) -> Dict[str, float]:

        features = np.array(
            [[
                waiting_farmers,
                processing_capacity,
                avg_processing_minutes,
                active_counters,
            ]],
            dtype=float,
        )

        if self.wait_time_model is not None:

            result = float(
                self.wait_time_model.predict(
                    features
                )[0]
            )

            return {
                "estimated_wait_minutes": round(
                    max(result, 0),
                    1,
                ),
                "confidence": 0.90,
                "model_used": "RandomForestRegressor",
            }

        # Safe deterministic fallback.
        result = (
            waiting_farmers
            * avg_processing_minutes
            / max(active_counters, 1)
        )

        return {
            "estimated_wait_minutes": round(
                max(result, 0),
                1,
            ),
            "confidence": 0.60,
            "model_used": "queue_fallback",
        }

    def predict_demand(
        self,
        current_hour: int,
        day_of_week: int,
        current_waiting: int,
        centre_capacity: int,
        historical_average: float,
        previous_hour_demand: int,
    ) -> Dict[str, float]:

        features = np.array(
            [[
                current_hour,
                day_of_week,
                current_waiting,
                centre_capacity,
                historical_average,
                previous_hour_demand,
            ]],
            dtype=float,
        )

        if self.demand_model is not None:

            result = float(
                self.demand_model.predict(
                    features
                )[0]
            )

            result = max(result, 0)

            if historical_average > 0:
                change = (
                    (result - historical_average)
                    / historical_average
                    * 100
                )
            else:
                change = 0

            return {
                "predicted_farmers": round(result),
                "demand_change_percentage": round(
                    change,
                    1,
                ),
                "confidence": 0.88,
                "model_used": "RandomForestRegressor",
            }

        hour_factor = 1.0

        if 10 <= current_hour <= 12:
            hour_factor = 1.25
        elif 13 <= current_hour <= 15:
            hour_factor = 1.10
        elif 16 <= current_hour <= 18:
            hour_factor = 0.90

        result = (
            historical_average * hour_factor
            + previous_hour_demand * 0.20
            + current_waiting * 0.10
        )

        if historical_average > 0:
            change = (
                (result - historical_average)
                / historical_average
                * 100
            )
        else:
            change = 0

        return {
            "predicted_farmers": round(
                max(result, 0)
            ),
            "demand_change_percentage": round(
                change,
                1,
            ),
            "confidence": 0.60,
            "model_used": "demand_fallback",
        }

    def predict_delay(
        self,
        queue_minutes: float,
        expected_arrivals: int,
        processing_capacity: int,
        avg_processing_minutes: float,
    ) -> Dict[str, float]:

        features = np.array(
            [[
                queue_minutes,
                expected_arrivals,
                processing_capacity,
                avg_processing_minutes,
            ]],
            dtype=float,
        )

        if self.delay_model is not None:

            probability = float(
                self.delay_model.predict_proba(
                    features
                )[0][1]
            )

            if probability >= 0.70:
                risk = "High"
            elif probability >= 0.40:
                risk = "Medium"
            else:
                risk = "Low"

            predicted_delay = (
                queue_minutes
                * (1 + probability)
            )

            return {
                "delay_risk": risk,
                "predicted_delay_minutes": round(
                    predicted_delay,
                    1,
                ),
                "probability": round(
                    probability,
                    3,
                ),
                "confidence": 0.86,
                "model_used": "RandomForestClassifier",
            }

        arrival_pressure = (
            expected_arrivals
            / max(processing_capacity, 1)
        )

        queue_pressure = (
            queue_minutes / 120
        )

        probability = min(
            max(
                (
                    arrival_pressure
                    + queue_pressure
                ) / 2,
                0,
            ),
            1,
        )

        if probability >= 0.70:
            risk = "High"
        elif probability >= 0.40:
            risk = "Medium"
        else:
            risk = "Low"

        predicted_delay = (
            queue_minutes
            + expected_arrivals
            * avg_processing_minutes
            / max(processing_capacity, 1)
        )

        return {
            "delay_risk": risk,
            "predicted_delay_minutes": round(
                predicted_delay,
                1,
            ),
            "probability": round(
                probability,
                3,
            ),
            "confidence": 0.60,
            "model_used": "delay_fallback",
        }


predictor = SmartProcurePredictor()