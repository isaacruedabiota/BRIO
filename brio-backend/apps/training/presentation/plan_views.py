"""
Rule-based training-plan generator (local, no external AI).
Direct ORM (like the rest of the training/social views).
"""
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.training.domain.plan_generator import (
    LEVEL_ES,
    MUSCLE_ES,
    generate_plan,
)
from apps.training.infrastructure.models import (
    ExerciseModel,
    RoutineExerciseModel,
    RoutineModel,
    TrainingPlanDayModel,
    TrainingPlanModel,
)


def _catalog() -> list[dict]:
    return [
        {"id": e.id, "name": e.name, "muscle_groups": e.muscle_groups or [], "equipment": e.equipment}
        for e in ExerciseModel.objects.all()
    ]


def _serialize_routine(routine) -> dict:
    rexs = (
        RoutineExerciseModel.objects.filter(routine=routine)
        .select_related("exercise").order_by("order")
    )
    exercises = []
    secs = 0
    tally: dict[str, int] = {}
    for re in rexs:
        secs += re.sets * (40 + re.rest_seconds)
        for m in (re.exercise.muscle_groups or []):
            tally[m] = tally.get(m, 0) + 1
        exercises.append({
            "exercise_id": re.exercise_id,
            "name": re.exercise.name,
            "muscle_groups": [MUSCLE_ES.get(m, m) for m in (re.exercise.muscle_groups or [])],
            "sets": re.sets, "reps": re.reps, "rest_seconds": re.rest_seconds,
        })
    top = sorted(tally, key=lambda m: -tally[m])[:3]
    return {
        "key": f"r{routine.id}",
        "name": routine.name,
        "muscle_groups": [MUSCLE_ES.get(m, m) for m in top],
        "est_min": round(secs / 60),
        "exercises": exercises,
    }


def _serialize_plan(plan) -> dict:
    days = list(plan.days.select_related("routine").all())
    routines = []
    key_by_routine: dict[int, str] = {}
    week = []
    has_cardio = False
    for d in days:
        if d.kind == "strength" and d.routine_id:
            if d.routine_id not in key_by_routine:
                r = _serialize_routine(d.routine)
                key_by_routine[d.routine_id] = r["key"]
                routines.append(r)
            week.append({"weekday": d.weekday, "kind": "strength",
                         "routine_key": key_by_routine[d.routine_id],
                         "routine_id": d.routine_id})
        elif d.kind in ("cardio", "mobility"):
            if d.kind == "cardio":
                has_cardio = True
            week.append({"weekday": d.weekday, "kind": d.kind, "name": d.label,
                         "activity_key": d.activity_key, "duration_min": d.duration_min})
        else:
            week.append({"weekday": d.weekday, "kind": "rest"})

    subtitle = LEVEL_ES.get(plan.level, "Intermedio")
    if has_cardio:
        subtitle += " · cardio incluido"

    return {
        "id": plan.id,
        "title": plan.name,
        "subtitle": subtitle,
        "goals": plan.goals or [],
        "level": plan.level,
        "days": sum(1 for d in days if d.kind == "strength"),
        "routines": routines,
        "week": week,
    }


class PlanGenerateView(APIView):
    """POST /api/training/plan/generate/ → preview a plan (doesn't save)."""
    permission_classes = [IsAuthenticated]

    def post(self, request: Request) -> Response:
        d = request.data
        try:
            days = int(d.get("days", 3))
        except (TypeError, ValueError):
            days = 3
        plan = generate_plan(
            goals=list(d.get("goals", [])),
            days=days,
            level=d.get("level", "intermediate"),
            equipment_ui=list(d.get("equipment", ["gym"])),
            include_cardio=bool(d.get("include_cardio", True)),
            exercises=_catalog(),
        )
        return Response(plan)


class PlanView(APIView):
    """
    GET    /api/training/plan/  → current plan (or null)
    POST   /api/training/plan/  → saves the plan (preview structure)
    DELETE /api/training/plan/  → deletes the current plan (keeps the routines)
    """
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        plan = TrainingPlanModel.objects.filter(user=request.user).first()
        return Response(_serialize_plan(plan) if plan else None)

    def post(self, request: Request) -> Response:
        data = request.data
        routines_in = data.get("routines", []) or []
        week_in = data.get("week", []) or []

        valid_ids = set(ExerciseModel.objects.values_list("id", flat=True))

        # Replaces the previous plan (keeps old routines in "My routines").
        TrainingPlanModel.objects.filter(user=request.user).delete()

        key_to_routine: dict[str, RoutineModel] = {}
        for r in routines_in:
            rm = RoutineModel.objects.create(
                user=request.user, name=(r.get("name") or "Rutina")[:200]
            )
            order = 0
            for ex in (r.get("exercises") or []):
                eid = ex.get("exercise_id")
                if eid not in valid_ids:
                    continue
                RoutineExerciseModel.objects.create(
                    routine=rm, exercise_id=eid,
                    sets=int(ex.get("sets", 3)),
                    reps=int(ex.get("reps", 10)),
                    rest_seconds=int(ex.get("rest_seconds", 90)),
                    order=order,
                )
                order += 1
            if r.get("key"):
                key_to_routine[r["key"]] = rm

        plan = TrainingPlanModel.objects.create(
            user=request.user,
            name=(data.get("title") or "Mi plan")[:200],
            goals=list(data.get("goals", [])),
            level=data.get("level", "intermediate"),
        )
        for w in week_in:
            kind = w.get("kind", "rest")
            TrainingPlanDayModel.objects.create(
                plan=plan,
                weekday=int(w.get("weekday", 0)),
                kind=kind,
                routine=key_to_routine.get(w.get("routine_key")) if kind == "strength" else None,
                activity_key=(w.get("activity_key") or ""),
                duration_min=w.get("duration_min"),
                label=(w.get("name") or ""),
            )

        return Response(_serialize_plan(plan), status=status.HTTP_201_CREATED)

    def delete(self, request: Request) -> Response:
        TrainingPlanModel.objects.filter(user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class PlanScheduleView(APIView):
    """
    PUT /api/training/plan/schedule/

    Sets the weekly schedule using routines that ALREADY EXIST (doesn't create any).
    Each day can have several activities (several rows with the same weekday).
    Body: {name?, days: [{weekday, kind, routine_id?, activity_key?, duration_min?, label?}]}
    """
    permission_classes = [IsAuthenticated]

    def put(self, request: Request) -> Response:
        data = request.data
        days_in = data.get("days", []) or []

        # Only the user's own routines (ownership validation).
        own = {r.id: r for r in RoutineModel.objects.filter(user=request.user)}

        plan = TrainingPlanModel.objects.filter(user=request.user).first()
        if plan is None:
            plan = TrainingPlanModel.objects.create(
                user=request.user,
                name=(data.get("name") or "Mi semana")[:200],
                goals=[], level="intermediate",
            )
        elif data.get("name"):
            plan.name = data["name"][:200]
            plan.save(update_fields=["name"])

        # Replaces the plan's days (keeps the routines in "My routines").
        plan.days.all().delete()
        for w in days_in:
            kind = w.get("kind", "rest")
            routine = None
            if kind == "strength":
                routine = own.get(w.get("routine_id"))
                if routine is None:
                    continue  # ignore routines that aren't the user's
            TrainingPlanDayModel.objects.create(
                plan=plan,
                weekday=int(w.get("weekday", 0)),
                kind=kind,
                routine=routine,
                activity_key=(w.get("activity_key") or ""),
                duration_min=w.get("duration_min"),
                label=(w.get("label") or w.get("name") or ""),
            )

        return Response(_serialize_plan(plan))
