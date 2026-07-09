"""
Entities and value objects for the nutrition module.
Zero Django imports. All calculation logic lives here.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from enum import Enum
from typing import Optional


class MealType(str, Enum):
    # The order defines how the day's meals are displayed.
    # Comments show the Spanish UI label for each key.
    BREAKFAST  = "breakfast"   # label: Desayuno
    MIDMORNING = "midmorning"  # label: Almuerzo (mid-morning)
    LUNCH      = "lunch"       # label: Comida
    MERIENDA   = "merienda"    # label: Merienda (mid-afternoon)
    DINNER     = "dinner"      # label: Cena


class FoodSource(str, Enum):
    OPEN_FOOD_FACTS = "openfoodfacts"
    MANUAL          = "manual"


# Value objects.

@dataclass(frozen=True)
class Macros:
    """Macros for a specific quantity of food."""
    kcal:      float
    protein_g: float
    carbs_g:   float
    fat_g:     float
    fiber_g:   float = 0.0

    def __add__(self, other: Macros) -> Macros:
        return Macros(
            kcal      = self.kcal      + other.kcal,
            protein_g = self.protein_g + other.protein_g,
            carbs_g   = self.carbs_g   + other.carbs_g,
            fat_g     = self.fat_g     + other.fat_g,
            fiber_g   = self.fiber_g   + other.fiber_g,
        )

    @classmethod
    def zero(cls) -> Macros:
        return cls(kcal=0, protein_g=0, carbs_g=0, fat_g=0, fiber_g=0)


# Entities.

@dataclass
class FoodItem:
    """
    A food from the database.
    Nutritional values are always per 100 g.
    """
    name:             str
    kcal_per_100g:    float
    protein_per_100g: float
    carbs_per_100g:   float
    fat_per_100g:     float
    id:               Optional[int]  = None
    barcode:          Optional[str]  = None
    brand:            Optional[str]  = None
    fiber_per_100g:   float          = 0.0
    source:           FoodSource     = FoodSource.MANUAL
    verified:         bool           = False
    created_by_id:    Optional[int]  = None   # None = food from the shared database

    # Domain logic.
    def macros_for(self, quantity_g: float) -> Macros:
        f = quantity_g / 100
        return Macros(
            kcal      = round(self.kcal_per_100g    * f, 1),
            protein_g = round(self.protein_per_100g * f, 1),
            carbs_g   = round(self.carbs_per_100g   * f, 1),
            fat_g     = round(self.fat_per_100g     * f, 1),
            fiber_g   = round(self.fiber_per_100g   * f, 1),
        )

    @property
    def display_name(self) -> str:
        return f"{self.name} — {self.brand}" if self.brand else self.name


@dataclass
class MealEntry:
    """A food logged by the user in a specific meal."""
    user_id:    int
    food_item:  FoodItem
    meal_type:  MealType
    quantity_g: float
    logged_at:  date
    id:         Optional[int] = None
    position:   int           = 0   # order within its meal

    @property
    def macros(self) -> Macros:
        return self.food_item.macros_for(self.quantity_g)


@dataclass
class DailyNutritionLog:
    """
    Aggregate consolidating all of a day's entries.
    Read-only — built from MealEntry objects from the repository.
    """
    date:    date
    user_id: int
    entries: list[MealEntry] = field(default_factory=list)

    # Day totals.
    @property
    def totals(self) -> Macros:
        from functools import reduce
        if not self.entries:
            return Macros.zero()
        return reduce(lambda a, b: a + b, (e.macros for e in self.entries))

    # Grouped by meal.
    @property
    def by_meal(self) -> dict[MealType, list[MealEntry]]:
        result: dict[MealType, list[MealEntry]] = {m: [] for m in MealType}
        for entry in self.entries:
            result[entry.meal_type].append(entry)
        return result

    def meal_totals(self, meal_type: MealType) -> Macros:
        entries = self.by_meal[meal_type]
        if not entries:
            return Macros.zero()
        from functools import reduce
        return reduce(lambda a, b: a + b, (e.macros for e in entries))
