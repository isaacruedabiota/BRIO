"""
Catalog of cardio/sport activities and calorie calculation from MET.

Standard formula:  kcal = MET x weight(kg) x duration(hours)
MET values come from the Compendium of Physical Activities.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Optional


@dataclass(frozen=True)
class ActivityType:
    key:           str      # stable identifier
    name_es:       str
    met:           float
    uses_distance: bool     # whether recording distance (km) makes sense
    icon:          str      # Material icon name (reference for the client)
    category:      str      # 'run' | 'bike' | 'sport' | 'other'


# Catalog (order = display order).
ACTIVITY_CATALOG: list[ActivityType] = [
    ActivityType("running",   "Correr",       9.8,  True,  "directions_run",     "run"),
    ActivityType("walking",   "Caminar",      3.5,  True,  "directions_walk",    "run"),
    ActivityType("cycling",   "Ciclismo",     8.0,  True,  "directions_bike",    "bike"),
    ActivityType("football",  "Fútbol",       7.0,  False, "sports_soccer",      "sport"),
    ActivityType("basketball","Baloncesto",   6.5,  False, "sports_basketball",  "sport"),
    ActivityType("tennis",    "Tenis",        7.3,  False, "sports_tennis",      "sport"),
    ActivityType("padel",     "Pádel",        6.0,  False, "sports_tennis",      "sport"),
    ActivityType("swimming",  "Natación",     8.0,  True,  "pool",               "other"),
    ActivityType("rowing",    "Remo",         7.0,  True,  "rowing",             "other"),
    ActivityType("elliptical","Elíptica",     5.0,  False, "fitness_center",     "other"),
    ActivityType("hiit",      "HIIT",         8.0,  False, "bolt",               "other"),
    ActivityType("jump_rope", "Comba",        11.0, False, "sports_mma",         "other"),
    ActivityType("other",     "Otro",         6.0,  False, "more_horiz",         "other"),
]

_BY_KEY = {a.key: a for a in ACTIVITY_CATALOG}

# Approximate MET for a strength-training session (moderate-to-vigorous effort).
STRENGTH_MET = 5.0


def met_for(key: str) -> float:
    a = _BY_KEY.get(key)
    return a.met if a else 6.0


def type_for(key: str) -> Optional[ActivityType]:
    return _BY_KEY.get(key)


def calories_for(met: float, weight_kg: float, duration_min: int) -> float:
    """kcal = MET x weight x hours."""
    return round(met * weight_kg * (duration_min / 60.0), 0)


@dataclass
class ActivityLog:
    user_id:       int
    activity_key:  str
    duration_min:  int
    performed_at:  date
    distance_km:   Optional[float] = None
    calories:      float           = 0.0
    id:            Optional[int]   = None
