from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.training.application.use_cases import (
    CreateRoutineInput,
    DeleteRoutineInput,
    DeleteSetInput,
    DeleteSetUseCase,
    FinishSessionInput,
    FinishWorkoutSessionUseCase,
    GetExerciseLibraryInput,
    GetExerciseLibraryUseCase,
    GetExerciseProgressUseCase,
    GetLastSetsInput,
    GetLastSetsUseCase,
    GetProgressInput,
    GetWorkoutHistoryUseCase,
    GetWorkoutSessionUseCase,
    GetHistoryInput,
    GetSessionInput,
    LogSetInput,
    LogSetUseCase,
    CreateRoutineUseCase,
    DeleteRoutineUseCase,
    StartSessionInput,
    StartWorkoutSessionUseCase,
    RoutineExerciseInput,
    UpdateRoutineInput,
    UpdateRoutineUseCase,
)
from apps.training.domain.entities import Equipment, MuscleGroup
from apps.training.infrastructure.repositories import (
    DjangoExerciseRepository,
    DjangoRoutineRepository,
    DjangoWorkoutSessionRepository,
)
from apps.training.presentation.serializers import (
    CreateRoutineSerializer,
    ExerciseSerializer,
    FinishSessionSerializer,
    LogSetSerializer,
    RoutineSerializer,
    StartSessionSerializer,
    WorkoutSessionSerializer,
    WorkoutSetSerializer,
)
from core.exceptions import (
    BusinessRuleViolationError,
    EntityNotFoundError,
    UnauthorizedError,
    ValidationError,
)


def _deps():
    return (
        DjangoExerciseRepository(),
        DjangoRoutineRepository(),
        DjangoWorkoutSessionRepository(),
    )


# Exercises.

class ExerciseLibraryView(APIView):
    """GET /api/training/exercises/?q=sentadilla&muscle=quads&equipment=barbell"""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        query     = request.query_params.get("q", "")
        muscle    = request.query_params.get("muscle")
        equipment = request.query_params.get("equipment")
        limit     = min(int(request.query_params.get("limit", 50)), 100)

        exercises, _, _ = _deps()
        results = GetExerciseLibraryUseCase(exercises).execute(
            GetExerciseLibraryInput(
                query        = query,
                muscle_group = MuscleGroup(muscle)    if muscle    else None,
                equipment    = Equipment(equipment)    if equipment else None,
                limit        = limit,
            )
        )
        return Response([ExerciseSerializer().to_representation(e) for e in results])


class ExerciseProgressView(APIView):
    """GET /api/training/exercises/{id}/progress/"""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request, exercise_id: int) -> Response:
        _, _, sessions = _deps()
        history = GetExerciseProgressUseCase(sessions).execute(
            GetProgressInput(user_id=request.user.pk, exercise_id=exercise_id)
        )
        return Response([{"date": str(d), "estimated_1rm": rm} for d, rm in history])


class ExerciseDetailView(APIView):
    """GET /api/training/exercises/{id}/ → exercise info (description, gif)."""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request, exercise_id: int) -> Response:
        exercises, _, _ = _deps()
        ex = exercises.find_by_id(exercise_id)
        if ex is None:
            return Response({"detail": "Ejercicio no encontrado."}, status=status.HTTP_404_NOT_FOUND)
        return Response(ExerciseSerializer().to_representation(ex))


class ExerciseLastSetsView(APIView):
    """GET /api/training/exercises/{id}/last-sets/ → sets from the last session."""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request, exercise_id: int) -> Response:
        _, _, sessions = _deps()
        sets = GetLastSetsUseCase(sessions).execute(
            GetLastSetsInput(user_id=request.user.pk, exercise_id=exercise_id)
        )
        return Response([
            {"set_number": s.set_number, "reps": s.reps, "weight_kg": s.weight_kg}
            for s in sets
        ])


# Routines.

class RoutineListView(APIView):
    """GET /api/training/routines/  |  POST /api/training/routines/"""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        _, routines, _ = _deps()
        user_routines = routines.find_by_user(request.user.pk)
        return Response([RoutineSerializer().to_representation(r) for r in user_routines])

    def post(self, request: Request) -> Response:
        s = CreateRoutineSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        data = s.validated_data

        exercises, routines, _ = _deps()
        try:
            routine = CreateRoutineUseCase(exercises, routines).execute(
                CreateRoutineInput(
                    user_id   = request.user.pk,
                    name      = data["name"],
                    exercises = [
                        RoutineExerciseInput(**ex)
                        for ex in data.get("exercises", [])
                    ],
                )
            )
        except (EntityNotFoundError, ValidationError) as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(
            RoutineSerializer().to_representation(routine),
            status=status.HTTP_201_CREATED,
        )


class RoutineDetailView(APIView):
    """PUT/DELETE /api/training/routines/{id}/"""
    permission_classes = [IsAuthenticated]

    def put(self, request: Request, routine_id: int) -> Response:
        s = CreateRoutineSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        data = s.validated_data

        exercises, routines, _ = _deps()
        try:
            routine = UpdateRoutineUseCase(exercises, routines).execute(
                UpdateRoutineInput(
                    routine_id = routine_id,
                    user_id    = request.user.pk,
                    name       = data["name"],
                    exercises  = [RoutineExerciseInput(**ex) for ex in data.get("exercises", [])],
                )
            )
        except EntityNotFoundError as e:
            return Response({"detail": str(e)}, status=status.HTTP_404_NOT_FOUND)
        except UnauthorizedError as e:
            return Response({"detail": str(e)}, status=status.HTTP_403_FORBIDDEN)
        return Response(RoutineSerializer().to_representation(routine))

    def delete(self, request: Request, routine_id: int) -> Response:
        _, routines, _ = _deps()
        try:
            DeleteRoutineUseCase(routines).execute(
                DeleteRoutineInput(routine_id=routine_id, user_id=request.user.pk)
            )
        except EntityNotFoundError as e:
            return Response({"detail": str(e)}, status=status.HTTP_404_NOT_FOUND)
        except UnauthorizedError as e:
            return Response({"detail": str(e)}, status=status.HTTP_403_FORBIDDEN)
        return Response(status=status.HTTP_204_NO_CONTENT)


# Sessions.

class WorkoutSessionListView(APIView):
    """
    GET  /api/training/sessions/  → history (completed sessions)
    POST /api/training/sessions/  → start a session
    """
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        _, _, sessions = _deps()
        history = GetWorkoutHistoryUseCase(sessions).execute(
            GetHistoryInput(user_id=request.user.pk)
        )
        return Response([WorkoutSessionSerializer().to_representation(s) for s in history])

    def post(self, request: Request) -> Response:
        s = StartSessionSerializer(data=request.data)
        s.is_valid(raise_exception=True)

        _, routines, sessions = _deps()
        try:
            session = StartWorkoutSessionUseCase(sessions, routines).execute(
                StartSessionInput(
                    user_id    = request.user.pk,
                    routine_id = s.validated_data.get("routine_id"),
                )
            )
        except (EntityNotFoundError, UnauthorizedError) as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)
        except BusinessRuleViolationError as e:
            return Response({"detail": str(e)}, status=status.HTTP_409_CONFLICT)

        return Response(
            WorkoutSessionSerializer().to_representation(session),
            status=status.HTTP_201_CREATED,
        )


class CurrentSessionView(APIView):
    """GET /api/training/sessions/active/ → the in-progress session, or null."""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        _, _, sessions = _deps()
        session = sessions.find_active(request.user.pk)
        if session is None:
            return Response(None)
        return Response(WorkoutSessionSerializer().to_representation(session))


class WorkoutSessionDetailView(APIView):
    """GET/DELETE /api/training/sessions/{id}/"""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request, session_id: int) -> Response:
        _, _, sessions = _deps()
        try:
            session = GetWorkoutSessionUseCase(sessions).execute(
                GetSessionInput(session_id=session_id, user_id=request.user.pk)
            )
        except (EntityNotFoundError, UnauthorizedError) as e:
            code = status.HTTP_404_NOT_FOUND if "encontrada" in str(e) else status.HTTP_403_FORBIDDEN
            return Response({"detail": str(e)}, status=code)
        return Response(WorkoutSessionSerializer().to_representation(session))

    def delete(self, request: Request, session_id: int) -> Response:
        """Discard a session (cancel workout)."""
        _, _, sessions = _deps()
        session = sessions.find_by_id(session_id)
        if session is None:
            return Response(status=status.HTTP_204_NO_CONTENT)
        if session.user_id != request.user.pk:
            return Response({"detail": "Sin permiso."}, status=status.HTTP_403_FORBIDDEN)
        sessions.delete(session_id)
        return Response(status=status.HTTP_204_NO_CONTENT)


class LogSetView(APIView):
    """POST /api/training/sessions/{id}/sets/"""
    permission_classes = [IsAuthenticated]

    def post(self, request: Request, session_id: int) -> Response:
        s = LogSetSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        data = s.validated_data

        exercises, _, sessions = _deps()
        try:
            workout_set = LogSetUseCase(sessions, exercises).execute(
                LogSetInput(
                    session_id  = session_id,
                    user_id     = request.user.pk,
                    exercise_id = data["exercise_id"],
                    reps        = data["reps"],
                    weight_kg   = data["weight_kg"],
                    set_number  = data["set_number"],
                    rpe         = data.get("rpe"),
                    set_type    = data.get("set_type", "normal"),
                )
            )
        except (EntityNotFoundError, ValidationError, BusinessRuleViolationError) as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)
        except UnauthorizedError as e:
            return Response({"detail": str(e)}, status=status.HTTP_403_FORBIDDEN)

        return Response(
            WorkoutSetSerializer().to_representation(workout_set),
            status=status.HTTP_201_CREATED,
        )


class DeleteSetView(APIView):
    """DELETE /api/training/sessions/{session_id}/sets/{set_id}/"""
    permission_classes = [IsAuthenticated]

    def delete(self, request: Request, session_id: int, set_id: int) -> Response:
        _, _, sessions = _deps()
        try:
            DeleteSetUseCase(sessions).execute(
                DeleteSetInput(session_id=session_id, set_id=set_id, user_id=request.user.pk)
            )
        except EntityNotFoundError as e:
            return Response({"detail": str(e)}, status=status.HTTP_404_NOT_FOUND)
        except UnauthorizedError as e:
            return Response({"detail": str(e)}, status=status.HTTP_403_FORBIDDEN)
        return Response(status=status.HTTP_204_NO_CONTENT)


class FinishSessionView(APIView):
    """POST /api/training/sessions/{id}/finish/"""
    permission_classes = [IsAuthenticated]

    def post(self, request: Request, session_id: int) -> Response:
        s = FinishSessionSerializer(data=request.data)
        s.is_valid(raise_exception=True)

        _, _, sessions = _deps()
        try:
            session = FinishWorkoutSessionUseCase(sessions).execute(
                FinishSessionInput(
                    session_id = session_id,
                    user_id    = request.user.pk,
                    notes      = s.validated_data.get("notes"),
                )
            )
        except (EntityNotFoundError, BusinessRuleViolationError) as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)
        except UnauthorizedError as e:
            return Response({"detail": str(e)}, status=status.HTTP_403_FORBIDDEN)

        # Estimate kcal burned in the strength session (MET x weight x duration).
        from apps.training.domain.activities import STRENGTH_MET, calories_for
        from apps.training.infrastructure.models import WorkoutSessionModel
        from apps.users.infrastructure.models import UserModel
        try:
            duration = session.duration_minutes or 0
            profile = getattr(UserModel.objects.get(pk=request.user.pk), "profile", None)
            weight = float(profile.weight_kg) if profile else 75.0
            kcal = calories_for(STRENGTH_MET, weight, duration)
            WorkoutSessionModel.objects.filter(pk=session_id).update(calories=kcal)
        except Exception:
            pass

        return Response(WorkoutSessionSerializer().to_representation(session))
