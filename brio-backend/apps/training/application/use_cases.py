from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional

from core.application.use_case import UseCase
from core.exceptions import (
    BusinessRuleViolationError,
    EntityNotFoundError,
    UnauthorizedError,
    ValidationError,
)
from apps.training.domain.entities import (
    Equipment,
    Exercise,
    MuscleGroup,
    Routine,
    RoutineExercise,
    SetType,
    WorkoutSession,
    WorkoutSet,
)
from apps.training.domain.repositories import (
    IExerciseRepository,
    IRoutineRepository,
    IWorkoutSessionRepository,
)


# DTOs.

@dataclass(frozen=True)
class GetExerciseLibraryInput:
    query:        str                   = ""
    muscle_group: Optional[MuscleGroup] = None
    equipment:    Optional[Equipment]   = None
    limit:        int                   = 50


@dataclass(frozen=True)
class RoutineExerciseInput:
    exercise_id:  int
    sets:         int
    reps:         int
    rest_seconds: int = 90
    order:        int = 0


@dataclass(frozen=True)
class CreateRoutineInput:
    user_id:   int
    name:      str
    exercises: list[RoutineExerciseInput] = field(default_factory=list)


@dataclass(frozen=True)
class UpdateRoutineInput:
    routine_id: int
    user_id:    int
    name:       str
    exercises:  list["RoutineExerciseInput"] = field(default_factory=list)


@dataclass(frozen=True)
class DeleteRoutineInput:
    routine_id: int
    user_id:    int


@dataclass(frozen=True)
class StartSessionInput:
    user_id:    int
    routine_id: Optional[int] = None


@dataclass(frozen=True)
class LogSetInput:
    session_id: int
    user_id:    int
    exercise_id: int
    reps:       int
    weight_kg:  float
    set_number: int
    rpe:        Optional[int] = None
    set_type:   str           = "normal"


@dataclass(frozen=True)
class DeleteSetInput:
    session_id: int
    set_id:     int
    user_id:    int


@dataclass(frozen=True)
class FinishSessionInput:
    session_id: int
    user_id:    int
    notes:      Optional[str] = None


@dataclass(frozen=True)
class GetSessionInput:
    session_id: int
    user_id:    int


@dataclass(frozen=True)
class GetHistoryInput:
    user_id: int
    limit:   int = 20


@dataclass(frozen=True)
class GetProgressInput:
    user_id:     int
    exercise_id: int
    limit:       int = 30


@dataclass(frozen=True)
class GetLastSetsInput:
    user_id:     int
    exercise_id: int


# Use cases.

class GetExerciseLibraryUseCase(UseCase[GetExerciseLibraryInput, list[Exercise]]):

    def __init__(self, exercise_repository: IExerciseRepository) -> None:
        self._repo = exercise_repository

    def execute(self, input_dto: GetExerciseLibraryInput) -> list[Exercise]:
        return self._repo.search(
            query        = input_dto.query,
            muscle_group = input_dto.muscle_group,
            equipment    = input_dto.equipment,
            limit        = input_dto.limit,
        )


class CreateRoutineUseCase(UseCase[CreateRoutineInput, Routine]):

    def __init__(
        self,
        exercise_repository: IExerciseRepository,
        routine_repository:  IRoutineRepository,
    ) -> None:
        self._exercises = exercise_repository
        self._routines  = routine_repository

    def execute(self, input_dto: CreateRoutineInput) -> Routine:
        if not input_dto.name.strip():
            raise ValidationError("El nombre de la rutina no puede estar vacío.")

        routine_exercises: list[RoutineExercise] = []
        for ex_input in input_dto.exercises:
            exercise = self._exercises.find_by_id(ex_input.exercise_id)
            if exercise is None:
                raise EntityNotFoundError(f"Ejercicio {ex_input.exercise_id} no encontrado.")
            routine_exercises.append(RoutineExercise(
                exercise     = exercise,
                sets         = ex_input.sets,
                reps         = ex_input.reps,
                rest_seconds = ex_input.rest_seconds,
                order        = ex_input.order,
            ))

        routine = Routine(
            user_id   = input_dto.user_id,
            name      = input_dto.name.strip(),
            exercises = routine_exercises,
        )
        return self._routines.save(routine)


class UpdateRoutineUseCase(UseCase[UpdateRoutineInput, Routine]):
    """Updates a routine's name and exercises (including rest_seconds)."""

    def __init__(
        self,
        exercise_repository: IExerciseRepository,
        routine_repository:  IRoutineRepository,
    ) -> None:
        self._exercises = exercise_repository
        self._routines  = routine_repository

    def execute(self, input_dto: UpdateRoutineInput) -> Routine:
        existing = self._routines.find_by_id(input_dto.routine_id)
        if existing is None:
            raise EntityNotFoundError(f"Rutina {input_dto.routine_id} no encontrada.")
        if existing.user_id != input_dto.user_id:
            raise UnauthorizedError("No tienes permiso para editar esta rutina.")

        routine_exercises: list[RoutineExercise] = []
        for ex_input in input_dto.exercises:
            exercise = self._exercises.find_by_id(ex_input.exercise_id)
            if exercise is None:
                raise EntityNotFoundError(f"Ejercicio {ex_input.exercise_id} no encontrado.")
            routine_exercises.append(RoutineExercise(
                exercise     = exercise,
                sets         = ex_input.sets,
                reps         = ex_input.reps,
                rest_seconds = ex_input.rest_seconds,
                order        = ex_input.order,
            ))

        updated = Routine(
            id        = input_dto.routine_id,
            user_id   = input_dto.user_id,
            name      = input_dto.name.strip() or existing.name,
            exercises = routine_exercises,
        )
        return self._routines.save(updated)


class DeleteRoutineUseCase(UseCase[DeleteRoutineInput, None]):

    def __init__(self, routine_repository: IRoutineRepository) -> None:
        self._repo = routine_repository

    def execute(self, input_dto: DeleteRoutineInput) -> None:
        routine = self._repo.find_by_id(input_dto.routine_id)
        if routine is None:
            raise EntityNotFoundError(f"Rutina {input_dto.routine_id} no encontrada.")
        if routine.user_id != input_dto.user_id:
            raise UnauthorizedError("No tienes permiso para borrar esta rutina.")
        self._repo.delete(input_dto.routine_id)


class StartWorkoutSessionUseCase(UseCase[StartSessionInput, WorkoutSession]):

    def __init__(
        self,
        session_repository: IWorkoutSessionRepository,
        routine_repository: IRoutineRepository,
    ) -> None:
        self._sessions = session_repository
        self._routines = routine_repository

    def execute(self, input_dto: StartSessionInput) -> WorkoutSession:
        # Rule: a user can only have one active session at a time.
        active = self._sessions.find_active(input_dto.user_id)
        if active:
            raise BusinessRuleViolationError(
                "Ya tienes una sesión activa. Termínala antes de empezar otra."
            )

        routine: Optional[Routine] = None
        if input_dto.routine_id:
            routine = self._routines.find_by_id(input_dto.routine_id)
            if routine is None:
                raise EntityNotFoundError(f"Rutina {input_dto.routine_id} no encontrada.")
            if routine.user_id != input_dto.user_id:
                raise UnauthorizedError("No tienes permiso para usar esta rutina.")

        session = WorkoutSession(
            user_id    = input_dto.user_id,
            routine    = routine,
            started_at = datetime.now(tz=timezone.utc),
        )
        return self._sessions.save(session)


class LogSetUseCase(UseCase[LogSetInput, WorkoutSet]):

    def __init__(
        self,
        session_repository:  IWorkoutSessionRepository,
        exercise_repository: IExerciseRepository,
    ) -> None:
        self._sessions  = session_repository
        self._exercises = exercise_repository

    def execute(self, input_dto: LogSetInput) -> WorkoutSet:
        if input_dto.reps <= 0:
            raise ValidationError("Las repeticiones deben ser mayor que 0.")
        if input_dto.weight_kg < 0:
            raise ValidationError("El peso no puede ser negativo.")
        if input_dto.rpe is not None and not (1 <= input_dto.rpe <= 10):
            raise ValidationError("El RPE debe estar entre 1 y 10.")

        session = self._sessions.find_by_id(input_dto.session_id)
        if session is None:
            raise EntityNotFoundError("Sesión no encontrada.")
        if session.user_id != input_dto.user_id:
            raise UnauthorizedError("No tienes permiso para modificar esta sesión.")
        if not session.is_active:
            raise BusinessRuleViolationError("La sesión ya ha terminado.")

        exercise = self._exercises.find_by_id(input_dto.exercise_id)
        if exercise is None:
            raise EntityNotFoundError(f"Ejercicio {input_dto.exercise_id} no encontrado.")

        try:
            set_type = SetType(input_dto.set_type)
        except ValueError:
            set_type = SetType.NORMAL

        workout_set = WorkoutSet(
            exercise   = exercise,
            reps       = input_dto.reps,
            weight_kg  = input_dto.weight_kg,
            set_number = input_dto.set_number,
            rpe        = input_dto.rpe,
            set_type   = set_type,
        )

        # Detect PR: only on sets that count (not warm-ups).
        if not workout_set.is_warmup:
            best_1rm = self._sessions.get_best_1rm(input_dto.user_id, input_dto.exercise_id)
            workout_set.is_pr = workout_set.estimated_1rm > best_1rm

        return self._sessions.add_set(input_dto.session_id, workout_set)


class DeleteSetUseCase(UseCase[DeleteSetInput, None]):

    def __init__(self, session_repository: IWorkoutSessionRepository) -> None:
        self._sessions = session_repository

    def execute(self, input_dto: DeleteSetInput) -> None:
        session = self._sessions.find_by_id(input_dto.session_id)
        if session is None:
            raise EntityNotFoundError("Sesión no encontrada.")
        if session.user_id != input_dto.user_id:
            raise UnauthorizedError("No tienes permiso para modificar esta sesión.")
        # The set must belong to this session.
        if not any(s.id == input_dto.set_id for s in session.sets):
            raise EntityNotFoundError("Serie no encontrada en esta sesión.")
        self._sessions.delete_set(input_dto.set_id)


class FinishWorkoutSessionUseCase(UseCase[FinishSessionInput, WorkoutSession]):

    def __init__(self, session_repository: IWorkoutSessionRepository) -> None:
        self._sessions = session_repository

    def execute(self, input_dto: FinishSessionInput) -> WorkoutSession:
        session = self._sessions.find_by_id(input_dto.session_id)
        if session is None:
            raise EntityNotFoundError("Sesión no encontrada.")
        if session.user_id != input_dto.user_id:
            raise UnauthorizedError("No tienes permiso para terminar esta sesión.")
        if not session.is_active:
            raise BusinessRuleViolationError("La sesión ya estaba terminada.")

        session.finished_at = datetime.now(tz=timezone.utc)
        session.notes       = input_dto.notes
        return self._sessions.save(session)


class GetWorkoutSessionUseCase(UseCase[GetSessionInput, WorkoutSession]):

    def __init__(self, session_repository: IWorkoutSessionRepository) -> None:
        self._sessions = session_repository

    def execute(self, input_dto: GetSessionInput) -> WorkoutSession:
        session = self._sessions.find_by_id(input_dto.session_id)
        if session is None:
            raise EntityNotFoundError("Sesión no encontrada.")
        if session.user_id != input_dto.user_id:
            raise UnauthorizedError("No tienes acceso a esta sesión.")
        return session


class GetWorkoutHistoryUseCase(UseCase[GetHistoryInput, list[WorkoutSession]]):

    def __init__(self, session_repository: IWorkoutSessionRepository) -> None:
        self._sessions = session_repository

    def execute(self, input_dto: GetHistoryInput) -> list[WorkoutSession]:
        return self._sessions.find_by_user(input_dto.user_id, input_dto.limit)


class GetExerciseProgressUseCase(UseCase[GetProgressInput, list[tuple]]):

    def __init__(self, session_repository: IWorkoutSessionRepository) -> None:
        self._sessions = session_repository

    def execute(self, input_dto: GetProgressInput) -> list[tuple]:
        return self._sessions.get_1rm_history(
            input_dto.user_id,
            input_dto.exercise_id,
            input_dto.limit,
        )


class GetLastSetsUseCase(UseCase[GetLastSetsInput, list[WorkoutSet]]):
    """Sets from the last session that included this exercise (Hevy-style reference)."""

    def __init__(self, session_repository: IWorkoutSessionRepository) -> None:
        self._sessions = session_repository

    def execute(self, input_dto: GetLastSetsInput) -> list[WorkoutSet]:
        return self._sessions.last_sets_for_exercise(
            input_dto.user_id, input_dto.exercise_id,
        )
