"""
Nutrition repository interfaces (the I + D of SOLID).
Minimal, separated interfaces: one per aggregate.
"""
from abc import abstractmethod
from datetime import date
from typing import Optional

from core.domain.repository import Repository
from apps.nutrition.domain.entities import FoodItem, MealEntry


class IFoodRepository(Repository[FoodItem, int]):

    @abstractmethod
    def search(self, query: str, limit: int = 20, user_id: Optional[int] = None) -> list[FoodItem]:
        """Searches the local DB + external sources and returns combined results.

        If `user_id` is passed, it includes that user's private foods on top of the
        shared database; it never returns other users' private foods.
        """
        ...

    @abstractmethod
    def find_by_barcode(self, barcode: str) -> Optional[FoodItem]:
        ...

    @abstractmethod
    def save_batch(self, items: list[FoodItem]) -> list[FoodItem]:
        """Persists several FoodItems at once (used to cache OFF results)."""
        ...


class IMealEntryRepository(Repository[MealEntry, int]):

    @abstractmethod
    def find_by_user_and_date(self, user_id: int, log_date: date) -> list[MealEntry]:
        ...

    @abstractmethod
    def apply_meal_order(self, entry_ids: list[int], meal_type) -> None:
        """Sets meal_type + position (= index in the list) for those entries.

        Used when reordering/moving entries with drag & drop: `entry_ids` is the
        desired final order of the `meal_type` meal.
        """
        ...

    @abstractmethod
    def find_recent_foods(self, user_id: int, limit: int = 15) -> list[FoodItem]:
        """The foods the user has logged most recently."""
        ...

    @abstractmethod
    def daily_kcal_for_month(
        self, user_id: int, year: int, month: int
    ) -> dict[str, float]:
        """Returns {'yyyy-MM-dd': total_kcal} for each day of the month with entries."""
        ...
