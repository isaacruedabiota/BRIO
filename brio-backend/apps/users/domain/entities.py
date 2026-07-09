"""
Domain entities: pure Python classes, no Django imports.
They hold the business logic (TDEE and macro calculation).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from enum import Enum
from typing import Optional


class FitnessGoal(str, Enum):
    LOSE_FAT = "lose_fat"
    GAIN_MUSCLE = "gain_muscle"
    IMPROVE_PERFORMANCE = "improve_performance"
    MAINTAIN = "maintain"


class ActivityLevel(str, Enum):
    SEDENTARY = "sedentary"
    LIGHTLY_ACTIVE = "lightly_active"
    ACTIVE = "active"
    VERY_ACTIVE = "very_active"


_ACTIVITY_MULTIPLIERS = {
    ActivityLevel.SEDENTARY: 1.2,
    ActivityLevel.LIGHTLY_ACTIVE: 1.375,
    ActivityLevel.ACTIVE: 1.55,
    ActivityLevel.VERY_ACTIVE: 1.725,
}

_GOAL_KCAL_DELTA = {
    FitnessGoal.LOSE_FAT: -400,
    FitnessGoal.GAIN_MUSCLE: +300,
    FitnessGoal.IMPROVE_PERFORMANCE: 0,
    FitnessGoal.MAINTAIN: 0,
}


@dataclass
class MacroTargets:
    kcal: int
    protein_g: int
    carbs_g: int
    fat_g: int


@dataclass
class UserProfile:
    goal: FitnessGoal
    weight_kg: float
    height_cm: int
    birth_date: date
    gender: str          # "M" | "F"
    activity_level: ActivityLevel
    training_days_per_week: int
    is_public: bool = True
    macro_targets: MacroTargets = field(init=False)

    def __post_init__(self) -> None:
        self.macro_targets = self._calculate_targets()

    # Pure business logic.
    def _calculate_targets(self) -> MacroTargets:
        bmr = self._mifflin_bmr()
        tdee = bmr * _ACTIVITY_MULTIPLIERS[self.activity_level]
        kcal = int(tdee + _GOAL_KCAL_DELTA[self.goal])

        protein_g = int(self.weight_kg * 2.0)           # 2 g / kg body weight
        fat_g = int(kcal * 0.25 / 9)                    # 25% kcal from fat
        carbs_g = int((kcal - protein_g * 4 - fat_g * 9) / 4)

        return MacroTargets(kcal=kcal, protein_g=protein_g, carbs_g=carbs_g, fat_g=fat_g)

    def _mifflin_bmr(self) -> float:
        base = 10 * self.weight_kg + 6.25 * self.height_cm - 5 * self._age()
        return base + 5 if self.gender == "M" else base - 161

    def _age(self) -> int:
        today = date.today()
        return today.year - self.birth_date.year - (
            (today.month, today.day) < (self.birth_date.month, self.birth_date.day)
        )


@dataclass
class User:
    email: str
    name: str
    id: Optional[int] = None
    profile: Optional[UserProfile] = None
    is_active: bool = True
    created_at: Optional[datetime] = None
