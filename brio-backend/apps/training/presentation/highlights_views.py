"""
"Highlights": computes the user's most impressive stats and returns the top 2
(by an impressiveness score). All from data that already exists (sets, volume,
streak, cardio activities).
"""
from datetime import date

from django.db.models import F, Sum
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.training.infrastructure.models import (
    ActivityLogModel,
    WorkoutSessionModel,
    WorkoutSetModel,
)

_MESES = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
          'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']

_ACTIVITY_ES = {
    'running': 'Correr', 'walking': 'Andar', 'cycling': 'Bici',
    'swimming': 'Natación', 'hiking': 'Senderismo', 'rowing': 'Remo',
}


def _best_lift(user) -> dict | None:
    best = None
    rows = (
        WorkoutSetModel.objects
        .filter(session__user=user, is_warmup=False, weight_kg__gt=0)
        .values("exercise__name", "weight_kg", "reps")
    )
    for s in rows:
        one_rm = s["weight_kg"] * (1 + s["reps"] / 30.0)   # Epley
        if best is None or one_rm > best[0]:
            best = (one_rm, s["exercise__name"])
    if best is None:
        return None
    one_rm, name = best
    return {
        "key": "lift", "icon": "trophy", "label": "Mejor marca",
        "value": round(one_rm), "unit": "kg", "name": name,
        "context": "1RM estimado", "score": one_rm,
    }


def _volume_month(user) -> dict | None:
    today = date.today()
    agg = (
        WorkoutSetModel.objects
        .filter(
            session__user=user, is_warmup=False,
            session__finished_at__year=today.year,
            session__finished_at__month=today.month,
        )
        .aggregate(v=Sum(F("weight_kg") * F("reps")))
    )
    v = agg["v"] or 0
    if v <= 0:
        return None
    if v >= 1000:
        value, unit = round(v / 1000.0, 1), "t"
    else:
        value, unit = round(v), "kg"
    return {
        "key": "volume", "icon": "chart", "label": "Volumen del mes",
        "value": value, "unit": unit, "name": _MESES[today.month].capitalize(),
        "context": "peso total levantado", "score": v * 0.003,
    }


def _longest_run(user) -> dict | None:
    a = (
        ActivityLogModel.objects
        .filter(user=user, distance_km__isnull=False, distance_km__gt=0)
        .order_by("-distance_km").first()
    )
    if a is None:
        return None
    return {
        "key": "run", "icon": "run", "label": "Distancia más larga",
        "value": round(a.distance_km, 1), "unit": "km",
        "name": _ACTIVITY_ES.get(a.activity_key, "Cardio"),
        "context": "tu mejor distancia", "score": a.distance_km * 6,
    }


def _best_streak(user) -> dict | None:
    days = set()
    for d in WorkoutSessionModel.objects.filter(
        user=user, finished_at__isnull=False
    ).values_list("finished_at", flat=True):
        days.add(d.date())
    for d in ActivityLogModel.objects.filter(user=user).values_list("performed_at", flat=True):
        days.add(d)
    if not days:
        return None
    ordered = sorted(days)
    best = cur = 1
    for i in range(1, len(ordered)):
        gap = (ordered[i] - ordered[i - 1]).days
        if gap == 1:
            cur += 1
            best = max(best, cur)
        elif gap > 1:
            cur = 1
    return {
        "key": "streak", "icon": "fire", "label": "Mejor racha",
        "value": best, "unit": "días" if best != 1 else "día", "name": "Constancia",
        "context": "tu récord personal", "score": best * 12,
    }


def _total_workouts(user) -> dict | None:
    n = WorkoutSessionModel.objects.filter(user=user, finished_at__isnull=False).count()
    if n <= 0:
        return None
    return {
        "key": "workouts", "icon": "dumbbell", "label": "Entrenos",
        "value": n, "unit": "", "name": "Total completados",
        "context": "sigue así", "score": n * 8,
    }


class HighlightsView(APIView):
    """GET /api/training/highlights/ → the 2 most impressive stats."""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        user = request.user
        metrics = [
            m for m in (
                _best_lift(user),
                _volume_month(user),
                _longest_run(user),
                _best_streak(user),
                _total_workouts(user),
            ) if m is not None
        ]
        metrics.sort(key=lambda m: m["score"], reverse=True)
        top = metrics[:2]
        for i, m in enumerate(top):
            m["hero"] = (i == 0)
            m.pop("score", None)
        return Response({"highlights": top})
