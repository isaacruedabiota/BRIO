"""
Domain entities for the training module.
All calculation logic (1RM, volume, PRs) lives here.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from enum import Enum
from typing import Optional


# Enums.

class MuscleGroup(str, Enum):
    CHEST      = "chest"
    BACK       = "back"
    SHOULDERS  = "shoulders"
    BICEPS     = "biceps"
    TRICEPS    = "triceps"
    QUADS      = "quads"
    HAMSTRINGS = "hamstrings"
    GLUTES     = "glutes"
    CALVES     = "calves"
    CORE       = "core"
    FOREARMS   = "forearms"
    FULL_BODY  = "full_body"


class Equipment(str, Enum):
    BARBELL    = "barbell"
    DUMBBELL   = "dumbbell"
    MACHINE    = "machine"
    CABLE      = "cable"
    BODYWEIGHT = "bodyweight"
    KETTLEBELL = "kettlebell"
    BANDS      = "bands"
    OTHER      = "other"


class SetType(str, Enum):
    NORMAL  = "normal"
    WARMUP  = "warmup"
    DROPSET = "dropset"
    FAILURE = "failure"


# Entities.

@dataclass
class Exercise:
    name:          str
    muscle_groups: list[MuscleGroup]
    equipment:     Equipment
    id:            Optional[int] = None
    instructions:  Optional[str] = None
    gif_url:       Optional[str] = None
    is_custom:     bool          = False


@dataclass
class RoutineExercise:
    exercise:     Exercise
    sets:         int
    reps:         int
    rest_seconds: int = 90
    order:        int = 0
    id:           Optional[int] = None


@dataclass
class Routine:
    user_id:   int
    name:      str
    exercises: list[RoutineExercise] = field(default_factory=list)
    id:        Optional[int]         = None


@dataclass
class WorkoutSet:
    exercise:   Exercise
    reps:       int
    weight_kg:  float
    set_number: int
    id:         Optional[int] = None
    rpe:        Optional[int] = None   # Rate of Perceived Exertion 1-10
    set_type:   SetType       = SetType.NORMAL
    is_pr:      bool          = False  # flagged by the repo when a PR is detected

    @property
    def is_warmup(self) -> bool:
        # Warm-ups don't count toward volume or PRs.
        return self.set_type == SetType.WARMUP

    # Domain logic.

    @property
    def estimated_1rm(self) -> float:
        """Epley formula: w x (1 + reps/30). For 1 rep returns the weight."""
        if self.reps <= 1:
            return self.weight_kg
        return round(self.weight_kg * (1 + self.reps / 30), 1)

    @property
    def volume(self) -> float:
        return round(self.weight_kg * self.reps, 1)


@dataclass
class WorkoutSession:
    user_id:     int
    id:          Optional[int]      = None
    routine:     Optional[Routine]  = None
    sets:        list[WorkoutSet]   = field(default_factory=list)
    started_at:  Optional[datetime] = None
    finished_at: Optional[datetime] = None
    notes:       Optional[str]      = None

    # Computed properties.

    @property
    def is_active(self) -> bool:
        return self.finished_at is None

    @property
    def duration_minutes(self) -> Optional[int]:
        if self.started_at and self.finished_at:
            return max(1, int((self.finished_at - self.started_at).seconds / 60))
        return None

    @property
    def total_volume_kg(self) -> float:
        return round(sum(s.volume for s in self.sets if not s.is_warmup), 1)

    @property
    def pr_count(self) -> int:
        return sum(1 for s in self.sets if s.is_pr)

    def sets_for_exercise(self, exercise_id: int) -> list[WorkoutSet]:
        return [s for s in self.sets if s.exercise.id == exercise_id]

    def best_set_for_exercise(self, exercise_id: int) -> Optional[WorkoutSet]:
        candidates = [s for s in self.sets_for_exercise(exercise_id) if not s.is_warmup]
        return max(candidates, key=lambda s: s.estimated_1rm) if candidates else None
