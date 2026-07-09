from abc import abstractmethod
from datetime import date
from typing import Optional

from core.domain.repository import Repository
from apps.training.domain.entities import Exercise, Equipment, MuscleGroup, Routine, WorkoutSession, WorkoutSet


class IExerciseRepository(Repository[Exercise, int]):

    @abstractmethod
    def search(
        self,
        query:        str                  = "",
        muscle_group: Optional[MuscleGroup] = None,
        equipment:    Optional[Equipment]   = None,
        limit:        int                  = 50,
    ) -> list[Exercise]:
        ...


class IRoutineRepository(Repository[Routine, int]):

    @abstractmethod
    def find_by_user(self, user_id: int) -> list[Routine]:
        ...


class IWorkoutSessionRepository(Repository[WorkoutSession, int]):

    @abstractmethod
    def find_active(self, user_id: int) -> Optional[WorkoutSession]:
        """The user's session without finished_at, if any."""
        ...

    @abstractmethod
    def find_by_user(self, user_id: int, limit: int = 20) -> list[WorkoutSession]:
        ...

    @abstractmethod
    def add_set(self, session_id: int, workout_set: WorkoutSet) -> WorkoutSet:
        ...

    @abstractmethod
    def delete_set(self, set_id: int) -> None:
        ...

    @abstractmethod
    def get_best_1rm(self, user_id: int, exercise_id: int) -> float:
        """The user's best historical estimated 1RM for that exercise."""
        ...

    @abstractmethod
    def get_1rm_history(
        self, user_id: int, exercise_id: int, limit: int = 30
    ) -> list[tuple[date, float]]:
        """List of (date, estimated 1RM) for plotting progress."""
        ...

    @abstractmethod
    def last_sets_for_exercise(
        self, user_id: int, exercise_id: int
    ) -> list[WorkoutSet]:
        """Non-warmup sets from the last completed session that included that
        exercise, ordered by set number."""
        ...
