"""
Rule-based training-plan generator (no AI, no external services).

Takes goals (multiple), days/week, level, equipment (multiple) and whether to
include cardio, and builds a weekly plan mixing strength days (routines with
catalog exercises) + cardio + mobility + rest.

Pure logic: receives the exercise catalog as a list of dicts and doesn't touch
Django or the DB. The presentation layer persists it.
"""
from __future__ import annotations

import random

# Spanish muscle labels (for display).
MUSCLE_ES = {
    "chest": "Pecho", "back": "Espalda", "shoulders": "Hombros",
    "biceps": "Bíceps", "triceps": "Tríceps", "quads": "Cuádriceps",
    "hamstrings": "Femoral", "glutes": "Glúteo", "calves": "Gemelos",
    "core": "Core", "forearms": "Antebrazo", "full_body": "Cuerpo completo",
}

GOAL_ES = {
    "lose_fat": "Perder grasa", "gain_muscle": "Ganar músculo",
    "gain_strength": "Ganar fuerza", "gain_endurance": "Ganar resistencia",
    "mobility": "Movilidad", "maintain": "Mantener",
}
LEVEL_ES = {"beginner": "Principiante", "intermediate": "Intermedio", "advanced": "Avanzado"}

# Equipment UI → set of catalog Equipment values.
EQUIP_MAP = {
    "gym":        {"barbell", "dumbbell", "machine", "cable", "kettlebell", "bands", "bodyweight", "other"},
    "dumbbell":   {"dumbbell", "bodyweight"},
    "bands":      {"bands", "bodyweight"},
    "kettlebell": {"kettlebell", "bodyweight"},
    "bodyweight": {"bodyweight"},
}
EQUIP_ES = {
    "gym": "Gimnasio", "dumbbell": "Mancuernas", "bands": "Bandas",
    "kettlebell": "Kettlebells", "bodyweight": "Peso corporal",
}

# Day templates: (name, [target groups]).
_PUSH  = ("Empuje", ["chest", "shoulders", "triceps"])
_PULL  = ("Tirón",  ["back", "biceps", "forearms"])
_LEGS  = ("Pierna", ["quads", "hamstrings", "glutes", "calves"])
_UPPER = ("Torso",  ["chest", "back", "shoulders", "biceps", "triceps"])
_LOWER = ("Pierna", ["quads", "hamstrings", "glutes", "calves", "core"])
_FULL  = ("Full body", ["chest", "back", "quads", "shoulders", "hamstrings", "core"])

# Number of exercises per day by level.
_EX_PER_DAY = {"beginner": 4, "intermediate": 5, "advanced": 6}

# Positions of strength days in the week (0=Monday), evenly spread.
_STRENGTH_POS = {
    1: [0], 2: [0, 3], 3: [0, 2, 4], 4: [0, 1, 3, 4],
    5: [0, 1, 2, 4, 5], 6: [0, 1, 2, 3, 4, 5], 7: [0, 1, 2, 3, 4, 5, 6],
}


def _split(days: int, level: str, goals: set[str]) -> list[tuple[str, list[str]]]:
    if days <= 1:
        return [_FULL]
    if days == 2:
        return [_UPPER, _LOWER]
    if days == 3:
        return [_FULL, _FULL, _FULL] if level == "beginner" else [_PUSH, _PULL, _LEGS]
    if days == 4:
        return [_UPPER, _LOWER, _UPPER, _LOWER]
    if days == 5:
        return [_PUSH, _PULL, _LEGS, _UPPER, _LOWER]
    if days == 6:
        return [_PUSH, _PULL, _LEGS, _PUSH, _PULL, _LEGS]
    return [_PUSH, _PULL, _LEGS, _UPPER, _LOWER, _FULL, _FULL]


def _scheme(goals: set[str], idx: int) -> tuple[int, int, int]:
    """(sets, reps, rest_seconds) based on goals and the exercise's position."""
    STRENGTH, HYP, ENDUR, FAT, MAINT = "strength", "hyp", "endur", "fat", "maint"
    table = {
        STRENGTH: (5, 5, 150), HYP: (4, 10, 90),
        ENDUR: (3, 18, 45), FAT: (3, 14, 60), MAINT: (3, 10, 90),
    }
    if "gain_strength" in goals:
        label = STRENGTH if idx < 2 else HYP   # heavy basics, accessories for hypertrophy
    elif "gain_muscle" in goals:
        label = HYP
    elif "gain_endurance" in goals:
        label = ENDUR
    elif "lose_fat" in goals:
        label = FAT
    else:
        label = MAINT

    sets, reps, rest = table[label]
    # Modifiers when goals are combined.
    if "gain_endurance" in goals and label != ENDUR:
        reps = min(reps + 4, 20)
        rest = max(rest - 20, 40)
    if "lose_fat" in goals and label != FAT:
        rest = max(rest - 20, 45)
    return sets, reps, rest


def _is_compound(ex: dict) -> bool:
    return len(ex.get("muscle_groups") or []) >= 2 or ex.get("equipment") == "barbell"


def _est_min(exercises: list[dict]) -> int:
    secs = sum(e["sets"] * (40 + e["rest_seconds"]) for e in exercises)
    return round(secs / 60)


def _cardio_plan(goals: set[str], level: str) -> tuple[int, list[dict]]:
    """(number of sessions, cardio-session template) based on goals."""
    if "lose_fat" in goals:
        count, dur, options = 3, 30, ["running", "walking", "cycling"]
    elif "gain_endurance" in goals:
        count, dur, options = 3, 35, ["running", "cycling", "running"]
    else:
        count, dur, options = 1, 25, ["walking", "running"]
    if level == "beginner":
        dur = max(20, dur - 10)
    names = {"running": "Correr", "walking": "Andar", "cycling": "Bici"}
    sessions = [
        {"activity_key": options[i % len(options)],
         "name": names[options[i % len(options)]], "duration_min": dur}
        for i in range(count)
    ]
    return count, sessions


def generate_plan(
    *,
    goals: list[str],
    days: int,
    level: str,
    equipment_ui: list[str],
    include_cardio: bool,
    exercises: list[dict],
) -> dict:
    goalset = set(goals) or {"maintain"}
    days = max(1, min(7, days))
    level = level if level in _EX_PER_DAY else "intermediate"
    rng = random.Random()

    # Allowed equipment (bodyweight always available as a wildcard).
    allowed = set()
    for e in (equipment_ui or ["gym"]):
        allowed |= EQUIP_MAP.get(e, set())
    allowed.add("bodyweight")

    # Muscle → exercise pools (allowed equipment, with any as a fallback).
    def by_muscle(pool_exs):
        d: dict[str, list[dict]] = {}
        for ex in pool_exs:
            for m in (ex.get("muscle_groups") or []):
                d.setdefault(m, []).append(ex)
        return d

    allowed_exs = [e for e in exercises if e.get("equipment") in allowed]
    pool = by_muscle(allowed_exs)
    pool_any = by_muscle(exercises)
    n_per_day = _EX_PER_DAY[level]

    templates = _split(days, level, goalset)

    # Names with an A/B suffix if a template repeats.
    name_counts: dict[str, int] = {}
    routines = []
    for di, (tname, muscles) in enumerate(templates):
        name_counts[tname] = name_counts.get(tname, 0) + 1

    seen_name: dict[str, int] = {}
    for di, (tname, muscles) in enumerate(templates):
        display = tname
        if name_counts[tname] > 1:
            seen_name[tname] = seen_name.get(tname, 0) + 1
            display = f"{tname} {chr(64 + seen_name[tname])}"  # A, B, C…

        chosen: list[dict] = []
        chosen_ids: set[int] = set()
        # Round-robin over target muscles.
        muscle_cycle = list(muscles)
        rng.shuffle(muscle_cycle)
        guard = 0
        while len(chosen) < n_per_day and guard < 40:
            guard += 1
            progressed = False
            for m in muscle_cycle:
                if len(chosen) >= n_per_day:
                    break
                cands = [e for e in pool.get(m, []) if e["id"] not in chosen_ids]
                if not cands:
                    cands = [e for e in pool_any.get(m, []) if e["id"] not in chosen_ids]
                if cands:
                    pick = rng.choice(cands)
                    chosen.append(pick)
                    chosen_ids.add(pick["id"])
                    progressed = True
            if not progressed:
                break

        # Fallback: if it came out too short, fill with any allowed exercise.
        if len(chosen) < 3:
            extra = [e for e in (allowed_exs or exercises) if e["id"] not in chosen_ids]
            rng.shuffle(extra)
            for e in extra:
                if len(chosen) >= max(3, n_per_day):
                    break
                chosen.append(e); chosen_ids.add(e["id"])

        # Compound exercises first, then assign sets/reps/rest.
        chosen.sort(key=lambda e: (not _is_compound(e)))
        ex_out = []
        for idx, e in enumerate(chosen):
            sets, reps, rest = _scheme(goalset, idx)
            ex_out.append({
                "exercise_id": e["id"],
                "name": e["name"],
                "muscle_groups": [MUSCLE_ES.get(m, m) for m in (e.get("muscle_groups") or [])],
                "sets": sets, "reps": reps, "rest_seconds": rest,
            })

        # Main muscle groups of the day (for the chips).
        tally: dict[str, int] = {}
        for e in chosen:
            for m in (e.get("muscle_groups") or []):
                tally[m] = tally.get(m, 0) + 1
        top = sorted(tally, key=lambda m: -tally[m])[:3]

        routines.append({
            "key": f"d{di}",
            "name": display,
            "muscle_groups": [MUSCLE_ES.get(m, m) for m in top],
            "est_min": _est_min(ex_out),
            "exercises": ex_out,
        })

    # Weekly distribution.
    positions = _STRENGTH_POS[days]
    week_kind: dict[int, dict] = {}
    for slot, wd in enumerate(positions):
        week_kind[wd] = {"weekday": wd, "kind": "strength", "routine_key": f"d{slot}"}

    off = [wd for wd in range(7) if wd not in week_kind]

    # Cardio on free days.
    if include_cardio and off:
        _, sessions = _cardio_plan(goalset, level)
        for s in sessions:
            if not off:
                break
            # keep Sunday (6) for rest if possible
            wd = next((w for w in off if w != 6), off[0])
            off.remove(wd)
            week_kind[wd] = {"weekday": wd, "kind": "cardio", **s}

    # Mobility (if among the goals) on a free day.
    if "mobility" in goalset and off:
        wd = next((w for w in off if w != 6), off[0])
        off.remove(wd)
        week_kind[wd] = {"weekday": wd, "kind": "mobility",
                         "name": "Movilidad", "duration_min": 15}

    # The rest: rest days.
    for wd in off:
        week_kind[wd] = {"weekday": wd, "kind": "rest"}

    week = [week_kind[wd] for wd in range(7)]

    # Header.
    goal_titles = [GOAL_ES[g] for g in ["gain_muscle", "gain_strength", "lose_fat",
                                        "gain_endurance", "mobility", "maintain"] if g in goalset]
    title = " + ".join(goal_titles) if goal_titles else "Plan de entreno"
    equip_titles = [EQUIP_ES[e] for e in (equipment_ui or ["gym"]) if e in EQUIP_ES]
    subtitle_parts = [LEVEL_ES.get(level, "Intermedio"), " + ".join(equip_titles) or "Gimnasio"]
    if include_cardio:
        subtitle_parts.append("cardio incluido")

    return {
        "title": title,
        "subtitle": " · ".join(subtitle_parts),
        "goals": sorted(goalset),
        "level": level,
        "days": days,
        "routines": routines,
        "week": week,
    }
