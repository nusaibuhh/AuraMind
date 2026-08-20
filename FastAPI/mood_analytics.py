"""Longitudinal mood analysis for AuraMind Module 1.

This module deliberately uses transparent, explainable rules instead of a
black-box ML model.  The CSE471 requirement is to detect continuous downward
trajectories and escalate a baseline intervention tier, so an auditable trend
rule is appropriate and easy to demonstrate during testing/viva.
"""

from __future__ import annotations

from statistics import mean
from typing import Dict, List


Point = Dict[str, object]


def _scores(points: List[Point]) -> List[float]:
    return [float(p["mood_score"]) for p in points]


def _linear_slope(points: List[Point]) -> float:
    """Return the least-squares slope in score-points per observation."""
    if len(points) < 2:
        return 0.0

    ys = _scores(points)
    xs = list(range(len(ys)))
    x_mean = mean(xs)
    y_mean = mean(ys)
    denominator = sum((x - x_mean) ** 2 for x in xs)
    if denominator == 0:
        return 0.0
    return sum((x - x_mean) * (y - y_mean) for x, y in zip(xs, ys)) / denominator


def _consecutive_declines(points: List[Point]) -> int:
    """Count consecutive declining transitions in the most recent run."""
    ys = _scores(points)
    if len(ys) < 2:
        return 0

    run = 0
    for i in range(len(ys) - 1, 0, -1):
        if ys[i] < ys[i - 1]:
            run += 1
        else:
            break
    return run


def _overall_change(points: List[Point]) -> float:
    if len(points) < 2:
        return 0.0
    return round(float(points[-1]["mood_score"]) - float(points[0]["mood_score"]), 2)


def detect_downward_trajectory(points: List[Point]) -> bool:
    """Detect a sustained decline rather than a single bad check-in.

    We require at least four observations, at least three consecutive
    declines at the end of the selected window, and an overall negative
    change. This keeps one-off fluctuations from triggering escalation.
    """
    if len(points) < 4:
        return False

    return _consecutive_declines(points) >= 3 and _overall_change(points) < 0


def determine_intervention(points: List[Point]) -> Dict[str, object]:
    if not points:
        return {
            "baseline_tier": 1,
            "tier": 1,
            "label": "Gentle Support",
            "message": "Complete a mood check-in to begin tracking your wellbeing trend.",
            "exercise": {
                "title": "3-Minute Breathing",
                "description": "Slow your breathing for a few minutes and give yourself a calm reset.",
                "icon": "self_improvement",
            },
        }

    latest = float(points[-1]["mood_score"])
    slope = _linear_slope(points)
    declining = detect_downward_trajectory(points)

    # Tier 1 is the baseline. A sustained decline raises the intervention
    # level; the latest score adds a second safety signal.
    tier = 1
    if slope < -0.15 or declining:
        tier = 2
    if declining and (slope < -0.30 or latest <= 5.0):
        tier = 3
    if latest <= 2.5 and declining:
        tier = 4

    recommendations = {
        1: {
            "label": "Maintaining Wellbeing",
            "message": "Your recent mood pattern looks relatively stable. Keep building small positive routines.",
            "exercise": {
                "title": "3-Minute Breathing",
                "description": "Try a short breathing reset to maintain a calm baseline.",
                "icon": "self_improvement",
            },
        },
        2: {
            "label": "Gentle Check-in",
            "message": "Your mood shows an early downward pattern. A small supportive activity may help interrupt it.",
            "exercise": {
                "title": "Grounding Reset",
                "description": "Use a 5-4-3-2-1 grounding exercise to reconnect with the present moment.",
                "icon": "spa",
            },
        },
        3: {
            "label": "Active Support",
            "message": "Your recent check-ins show a sustained downward trajectory. Consider a more active wellbeing exercise today.",
            "exercise": {
                "title": "Mood Momentum Walk",
                "description": "Take a gentle 5–10 minute walk and focus on your surroundings while moving.",
                "icon": "directions_walk",
            },
        },
        4: {
            "label": "Additional Support",
            "message": "Your recent scores indicate significant deterioration. Consider reaching out to someone you trust or a qualified mental-health professional.",
            "exercise": {
                "title": "Reach Out",
                "description": "Contact a trusted person or use the professional-support options available in AuraMind.",
                "icon": "support_agent",
            },
        },
    }

    selected = recommendations[tier]
    return {
        "baseline_tier": 1,
        "tier": tier,
        **selected,
    }


def analyze_mood_history(points: List[Point]) -> Dict[str, object]:
    if not points:
        return {
            "trend": 0.0,
            "trend_label": "No data yet",
            "is_declining": False,
            "consecutive_declines": 0,
            "overall_change": 0.0,
            "slope": 0.0,
            "intervention": determine_intervention(points),
        }

    slope = _linear_slope(points)
    change = _overall_change(points)
    declining = detect_downward_trajectory(points)

    if slope > 0.10:
        label = "Improving"
    elif slope < -0.10:
        label = "Declining"
    else:
        label = "Stable"

    return {
        "trend": round(slope, 3),
        "trend_label": label,
        "is_declining": declining,
        "consecutive_declines": _consecutive_declines(points),
        "overall_change": change,
        "slope": round(slope, 3),
        "intervention": determine_intervention(points),
    }
