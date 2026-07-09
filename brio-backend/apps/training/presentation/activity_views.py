"""
Endpoints for cardio/sport activities and the day's burned calories.
The calculation logic (MET → kcal) lives in the domain (apps.training.domain.activities).
"""
from datetime import date

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.training.domain.activities import (
    ACTIVITY_CATALOG, STRENGTH_MET, calories_for, met_for, type_for,
)
from apps.training.infrastructure.models import ActivityLogModel, WorkoutSessionModel


def _user_weight(user) -> float:
    profile = getattr(user, "profile", None)
    return float(profile.weight_kg) if profile else 75.0


class ActivityCatalogView(APIView):
    """GET /api/training/activities/catalog/ → available activity types."""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        return Response([
            {
                "key": a.key, "name": a.name_es, "met": a.met,
                "uses_distance": a.uses_distance, "icon": a.icon, "category": a.category,
            }
            for a in ACTIVITY_CATALOG
        ])


class ActivityListView(APIView):
    """
    GET  /api/training/activities/?date=YYYY-MM-DD  → activities for that day
    POST /api/training/activities/                  → log an activity
    """
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        raw = request.query_params.get("date")
        qs = ActivityLogModel.objects.filter(user=request.user)
        if raw:
            # Filter by a specific day.
            try:
                d = date.fromisoformat(raw)
            except ValueError:
                return Response({"detail": "Fecha inválida."}, status=400)
            qs = qs.filter(performed_at=d).order_by("-created_at")
        else:
            # Full history.
            qs = qs.order_by("-performed_at", "-created_at")
        return Response([_serialize(a) for a in qs])

    def post(self, request: Request) -> Response:
        data = request.data
        key = data.get("activity_key", "other")
        duration = int(data.get("duration_min", 0))
        if duration <= 0:
            return Response({"detail": "La duración debe ser mayor que 0."}, status=400)
        distance = data.get("distance_km")
        performed = data.get("performed_at")
        route = data.get("route") or []
        try:
            d = date.fromisoformat(performed) if performed else date.today()
        except ValueError:
            d = date.today()

        kcal = calories_for(met_for(key), _user_weight(request.user), duration)
        log = ActivityLogModel.objects.create(
            user=request.user, activity_key=key, duration_min=duration,
            distance_km=distance, calories=kcal, performed_at=d, route=route,
        )
        return Response(_serialize(log), status=status.HTTP_201_CREATED)


class ActivityDetailView(APIView):
    """DELETE /api/training/activities/{id}/"""
    permission_classes = [IsAuthenticated]

    def delete(self, request: Request, activity_id: int) -> Response:
        ActivityLogModel.objects.filter(pk=activity_id, user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class BurnedCaloriesView(APIView):
    """GET /api/training/burned/?date=YYYY-MM-DD → kcal burned (cardio + strength)."""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        raw = request.query_params.get("date", str(date.today()))
        try:
            d = date.fromisoformat(raw)
        except ValueError:
            return Response({"detail": "Fecha inválida."}, status=400)

        cardio = sum(
            a.calories for a in
            ActivityLogModel.objects.filter(user=request.user, performed_at=d)
        )
        strength = sum(
            s.calories for s in
            WorkoutSessionModel.objects.filter(
                user=request.user, finished_at__date=d, finished_at__isnull=False)
        )
        return Response({
            "date": str(d),
            "cardio": round(cardio),
            "strength": round(strength),
            "total": round(cardio + strength),
        })


def _serialize(a: ActivityLogModel) -> dict:
    t = type_for(a.activity_key)
    return {
        "id": a.pk,
        "activity_key": a.activity_key,
        "name": t.name_es if t else a.activity_key,
        "icon": t.icon if t else "more_horiz",
        "category": t.category if t else "other",
        "duration_min": a.duration_min,
        "distance_km": a.distance_km,
        "calories": a.calories,
        "route": a.route or [],
        "performed_at": str(a.performed_at),
    }
