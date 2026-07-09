from __future__ import annotations

from datetime import date
from typing import Optional

from django.db.models import Max

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
from apps.training.infrastructure.models import (
    ExerciseModel,
    RoutineExerciseModel,
    RoutineModel,
    WorkoutSessionModel,
    WorkoutSetModel,
)


class DjangoExerciseRepository(IExerciseRepository):

    def find_by_id(self, entity_id: int) -> Optional[Exercise]:
        try:
            return self._to_entity(ExerciseModel.objects.get(pk=entity_id))
        except ExerciseModel.DoesNotExist:
            return None

    def search(
        self,
        query:        str                   = "",
        muscle_group: Optional[MuscleGroup] = None,
        equipment:    Optional[Equipment]   = None,
        limit:        int                   = 50,
    ) -> list[Exercise]:
        qs = ExerciseModel.objects.all()
        if query:
            qs = qs.filter(name__icontains=query)
        if equipment:
            qs = qs.filter(equipment=equipment.value)

        results = [self._to_entity(m) for m in qs.order_by("name")]

        # Filter in Python: JSONField.__contains isn't supported on SQLite.
        if muscle_group:
            results = [e for e in results if muscle_group in e.muscle_groups]

        return results[:limit]

    def save(self, entity: Exercise) -> Exercise:
        if entity.id is not None:
            ExerciseModel.objects.filter(pk=entity.id).update(
                name          = entity.name,
                muscle_groups = [g.value for g in entity.muscle_groups],
                equipment     = entity.equipment.value,
                instructions  = entity.instructions,
            )
            return self._to_entity(ExerciseModel.objects.get(pk=entity.id))
        model = ExerciseModel.objects.create(
            name          = entity.name,
            muscle_groups = [g.value for g in entity.muscle_groups],
            equipment     = entity.equipment.value,
            instructions  = entity.instructions,
            is_custom     = entity.is_custom,
        )
        return self._to_entity(model)

    def delete(self, entity_id: int) -> None:
        ExerciseModel.objects.filter(pk=entity_id).delete()

    @staticmethod
    def _to_entity(m: ExerciseModel) -> Exercise:
        return Exercise(
            id            = m.pk,
            name          = m.name,
            muscle_groups = [MuscleGroup(g) for g in (m.muscle_groups or [])],
            equipment     = Equipment(m.equipment),
            instructions  = m.instructions,
            gif_url       = m.gif_url,
            is_custom     = m.is_custom,
        )


class DjangoRoutineRepository(IRoutineRepository):

    def find_by_id(self, entity_id: int) -> Optional[Routine]:
        try:
            m = RoutineModel.objects.prefetch_related(
                "routine_exercises__exercise"
            ).get(pk=entity_id)
            return self._to_entity(m)
        except RoutineModel.DoesNotExist:
            return None

    def find_by_user(self, user_id: int) -> list[Routine]:
        qs = RoutineModel.objects.prefetch_related(
            "routine_exercises__exercise"
        ).filter(user_id=user_id).order_by("name")
        return [self._to_entity(m) for m in qs]

    def save(self, entity: Routine) -> Routine:
        if entity.id is not None:
            RoutineModel.objects.filter(pk=entity.id).update(name=entity.name)
            model = RoutineModel.objects.get(pk=entity.id)
        else:
            model = RoutineModel.objects.create(user_id=entity.user_id, name=entity.name)

        # Replace exercises entirely (simplifies update logic).
        RoutineExerciseModel.objects.filter(routine=model).delete()
        for re in entity.exercises:
            RoutineExerciseModel.objects.create(
                routine_id   = model.pk,
                exercise_id  = re.exercise.id,
                sets         = re.sets,
                reps         = re.reps,
                rest_seconds = re.rest_seconds,
                order        = re.order,
            )
        return self.find_by_id(model.pk)

    def delete(self, entity_id: int) -> None:
        RoutineModel.objects.filter(pk=entity_id).delete()

    @staticmethod
    def _to_entity(m: RoutineModel) -> Routine:
        exercises = [
            RoutineExercise(
                id           = re.pk,
                exercise     = DjangoExerciseRepository._to_entity(re.exercise),
                sets         = re.sets,
                reps         = re.reps,
                rest_seconds = re.rest_seconds,
                order        = re.order,
            )
            for re in m.routine_exercises.all()
        ]
        return Routine(id=m.pk, user_id=m.user_id, name=m.name, exercises=exercises)


class DjangoWorkoutSessionRepository(IWorkoutSessionRepository):

    def find_by_id(self, entity_id: int) -> Optional[WorkoutSession]:
        try:
            m = WorkoutSessionModel.objects.prefetch_related(
                "sets__exercise"
            ).select_related("routine").get(pk=entity_id)
            return self._to_entity(m)
        except WorkoutSessionModel.DoesNotExist:
            return None

    def find_active(self, user_id: int) -> Optional[WorkoutSession]:
        try:
            m = WorkoutSessionModel.objects.prefetch_related(
                "sets__exercise"
            ).get(user_id=user_id, finished_at__isnull=True)
            return self._to_entity(m)
        except WorkoutSessionModel.DoesNotExist:
            return None

    def find_by_user(self, user_id: int, limit: int = 20) -> list[WorkoutSession]:
        qs = (
            WorkoutSessionModel.objects
            .prefetch_related("sets__exercise")
            .select_related("routine")
            .filter(user_id=user_id, finished_at__isnull=False)
            .order_by("-finished_at")[:limit]
        )
        return [self._to_entity(m) for m in qs]

    def save(self, entity: WorkoutSession) -> WorkoutSession:
        if entity.id is not None:
            WorkoutSessionModel.objects.filter(pk=entity.id).update(
                finished_at = entity.finished_at,
                notes       = entity.notes,
            )
            return self.find_by_id(entity.id)

        model = WorkoutSessionModel.objects.create(
            user_id    = entity.user_id,
            routine_id = entity.routine.id if entity.routine else None,
            started_at = entity.started_at,
        )
        return self.find_by_id(model.pk)

    def add_set(self, session_id: int, workout_set: WorkoutSet) -> WorkoutSet:
        model = WorkoutSetModel.objects.create(
            session_id = session_id,
            exercise_id= workout_set.exercise.id,
            reps       = workout_set.reps,
            weight_kg  = workout_set.weight_kg,
            set_number = workout_set.set_number,
            rpe        = workout_set.rpe,
            set_type   = workout_set.set_type.value,
            is_warmup  = workout_set.is_warmup,
            is_pr      = workout_set.is_pr,
        )
        return WorkoutSet(
            id         = model.pk,
            exercise   = workout_set.exercise,
            reps       = model.reps,
            weight_kg  = model.weight_kg,
            set_number = model.set_number,
            rpe        = model.rpe,
            set_type   = SetType(model.set_type),
            is_pr      = model.is_pr,
        )

    def delete_set(self, set_id: int) -> None:
        WorkoutSetModel.objects.filter(pk=set_id).delete()

    def delete(self, entity_id: int) -> None:
        WorkoutSessionModel.objects.filter(pk=entity_id).delete()

    def get_best_1rm(self, user_id: int, exercise_id: int) -> float:
        """Computes the best historical estimated 1RM for an exercise."""
        sets = (
            WorkoutSetModel.objects
            .filter(
                session__user_id=user_id,
                exercise_id=exercise_id,
                is_warmup=False,
            )
            .values_list("weight_kg", "reps")
        )
        if not sets:
            return 0.0
        return max(
            w * (1 + r / 30) if r > 1 else w
            for w, r in sets
        )

    def get_1rm_history(
        self, user_id: int, exercise_id: int, limit: int = 30
    ) -> list[tuple[date, float]]:
        sessions = (
            WorkoutSessionModel.objects
            .filter(
                user_id=user_id,
                finished_at__isnull=False,
                sets__exercise_id=exercise_id,
                sets__is_warmup=False,
            )
            .distinct()
            .order_by("-finished_at")[:limit]
        )
        result = []
        for session in sessions:
            day_sets = WorkoutSetModel.objects.filter(
                session=session,
                exercise_id=exercise_id,
                is_warmup=False,
            ).values_list("weight_kg", "reps")
            if not day_sets:
                continue
            best = max(
                w * (1 + r / 30) if r > 1 else w
                for w, r in day_sets
            )
            result.append((session.finished_at.date(), round(best, 1)))
        return result

    def last_sets_for_exercise(self, user_id: int, exercise_id: int) -> list[WorkoutSet]:
        last_session = (
            WorkoutSessionModel.objects
            .filter(
                user_id=user_id,
                finished_at__isnull=False,
                sets__exercise_id=exercise_id,
                sets__is_warmup=False,
            )
            .distinct()
            .order_by("-finished_at")
            .first()
        )
        if last_session is None:
            return []

        exercise = ExerciseModel.objects.filter(pk=exercise_id).first()
        if exercise is None:
            return []
        domain_ex = DjangoExerciseRepository._to_entity(exercise)

        qs = (
            WorkoutSetModel.objects
            .filter(session=last_session, exercise_id=exercise_id, is_warmup=False)
            .order_by("set_number")
        )
        return [
            WorkoutSet(
                id         = s.pk,
                exercise   = domain_ex,
                reps       = s.reps,
                weight_kg  = s.weight_kg,
                set_number = s.set_number,
                rpe        = s.rpe,
                set_type   = SetType(s.set_type),
                is_pr      = s.is_pr,
            )
            for s in qs
        ]

    @staticmethod
    def _to_entity(m: WorkoutSessionModel) -> WorkoutSession:
        routine = None
        if m.routine_id:
            routine = Routine(
                id       = m.routine.pk,
                user_id  = m.user_id,
                name     = m.routine.name,
            )

        sets = [
            WorkoutSet(
                id         = s.pk,
                exercise   = DjangoExerciseRepository._to_entity(s.exercise),
                reps       = s.reps,
                weight_kg  = s.weight_kg,
                set_number = s.set_number,
                rpe        = s.rpe,
                set_type   = SetType(s.set_type),
                is_pr      = s.is_pr,
            )
            for s in m.sets.all()
        ]

        return WorkoutSession(
            id          = m.pk,
            user_id     = m.user_id,
            routine     = routine,
            sets        = sets,
            started_at  = m.started_at,
            finished_at = m.finished_at,
            notes       = m.notes,
        )
