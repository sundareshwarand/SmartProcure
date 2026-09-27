from __future__ import annotations

from datetime import datetime
from typing import Dict


def calculate_queue_features(
    waiting_farmers: int,
    processing_capacity: int,
    avg_processing_minutes: float,
    active_counters: int,
) -> Dict[str, float]:

    safe_capacity = max(processing_capacity, 1)
    safe_counters = max(active_counters, 1)
    safe_processing = max(avg_processing_minutes, 1.0)

    utilization = waiting_farmers / safe_capacity

    estimated_queue_minutes = (
        waiting_farmers
        * safe_processing
        / safe_counters
    )

    return {
        "waiting_farmers": float(waiting_farmers),
        "processing_capacity": float(processing_capacity),
        "avg_processing_minutes": float(avg_processing_minutes),
        "active_counters": float(active_counters),
        "utilization": float(utilization),
        "estimated_queue_minutes": float(
            estimated_queue_minutes
        ),
    }


def calculate_congestion_level(
    utilization: float,
    waiting_farmers: int,
) -> str:

    if utilization >= 0.90 or waiting_farmers >= 100:
        return "High"

    if utilization >= 0.65 or waiting_farmers >= 50:
        return "Medium"

    return "Low"


def calculate_delay_features(
    queue_minutes: float,
    expected_arrivals: int,
    processing_capacity: int,
    avg_processing_minutes: float,
) -> Dict[str, float]:

    safe_capacity = max(processing_capacity, 1)

    arrival_pressure = (
        expected_arrivals / safe_capacity
    )

    projected_delay = (
        queue_minutes
        + (
            expected_arrivals
            * avg_processing_minutes
            / safe_capacity
        )
    )

    return {
        "queue_minutes": float(queue_minutes),
        "expected_arrivals": float(expected_arrivals),
        "processing_capacity": float(processing_capacity),
        "avg_processing_minutes": float(
            avg_processing_minutes
        ),
        "arrival_pressure": float(arrival_pressure),
        "projected_delay": float(projected_delay),
    }


def get_current_hour() -> int:
    return datetime.now().hour