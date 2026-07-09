"""
Nutrition use cases.
No Django imports — testable with mock repositories.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Optional

from core.application.use_case import UseCase
from core.exceptions import EntityNotFoundError, ValidationError
from apps.nutrition.domain.entities import (
    DailyNutritionLog,
    FoodItem,
    FoodSource,
    MealEntry,
    MealType,
)
from apps.nutrition.domain.repositories import IFoodRepository, IMealEntryRepository


# DTOs.

@dataclass(frozen=True)
class SearchFoodInput:
    query: str
    limit: int = 20
    user_id: Optional[int] = None


@dataclass(frozen=True)
class CreateFoodInput:
    user_id:          int
    name:             str
    kcal_per_100g:    float
    protein_per_100g: float
    carbs_per_100g:   float
    fat_per_100g:     float
    fiber_per_100g:   float         = 0.0
    brand:            Optional[str] = None


@dataclass(frozen=True)
class GetFoodByBarcodeInput:
    barcode: str


@dataclass(frozen=True)
class LogMealInput:
    user_id:    int
    food_id:    int
    meal_type:  MealType
    quantity_g: float
    logged_at:  date


@dataclass(frozen=True)
class DeleteMealEntryInput:
    entry_id: int
    user_id:  int          # to verify ownership


@dataclass(frozen=True)
class MoveMealEntryInput:
    entry_id:  int
    user_id:   int                  # to verify ownership
    meal_type: MealType             # destination meal
    position:  Optional[int] = None  # target index within the meal (None = at the end)


@dataclass(frozen=True)
class GetDailyLogInput:
    user_id:  int
    log_date: date


@dataclass(frozen=True)
class GetRecentFoodsInput:
    user_id: int
    limit:   int = 15


@dataclass(frozen=True)
class GetMonthlySummaryInput:
    user_id: int
    year:    int
    month:   int


# Use cases.

class SearchFoodUseCase(UseCase[SearchFoodInput, list[FoodItem]]):
    """
    Searches foods combining the local DB and Open Food Facts.
    The cache-aside strategy lives in the concrete repository.
    """

    def __init__(self, food_repository: IFoodRepository) -> None:
        self._repo = food_repository

    def execute(self, input_dto: SearchFoodInput) -> list[FoodItem]:
        if len(input_dto.query.strip()) < 2:
            raise ValidationError("La búsqueda debe tener al menos 2 caracteres.")
        return self._repo.search(
            input_dto.query.strip(),
            limit=input_dto.limit,
            user_id=input_dto.user_id,
        )


class CreateFoodUseCase(UseCase[CreateFoodInput, FoodItem]):
    """Creates a user's private food (created_by = user)."""

    def __init__(self, food_repository: IFoodRepository) -> None:
        self._repo = food_repository

    def execute(self, input_dto: CreateFoodInput) -> FoodItem:
        name = input_dto.name.strip()
        if len(name) < 2:
            raise ValidationError("El nombre debe tener al menos 2 caracteres.")
        for label, value in (
            ("calorías", input_dto.kcal_per_100g),
            ("proteínas", input_dto.protein_per_100g),
            ("carbohidratos", input_dto.carbs_per_100g),
            ("grasas", input_dto.fat_per_100g),
            ("fibra", input_dto.fiber_per_100g),
        ):
            if value < 0:
                raise ValidationError(f"Las {label} no pueden ser negativas.")

        food = FoodItem(
            name             = name,
            brand            = (input_dto.brand or "").strip() or None,
            kcal_per_100g    = input_dto.kcal_per_100g,
            protein_per_100g = input_dto.protein_per_100g,
            carbs_per_100g   = input_dto.carbs_per_100g,
            fat_per_100g     = input_dto.fat_per_100g,
            fiber_per_100g   = input_dto.fiber_per_100g,
            source           = FoodSource.MANUAL,
            verified         = False,
            created_by_id    = input_dto.user_id,
        )
        return self._repo.save(food)


class GetFoodByBarcodeUseCase(UseCase[GetFoodByBarcodeInput, FoodItem]):

    def __init__(self, food_repository: IFoodRepository) -> None:
        self._repo = food_repository

    def execute(self, input_dto: GetFoodByBarcodeInput) -> FoodItem:
        food = self._repo.find_by_barcode(input_dto.barcode)
        if food is None:
            raise EntityNotFoundError(
                f"No se encontró ningún alimento con código {input_dto.barcode!r}."
            )
        return food


class LogMealUseCase(UseCase[LogMealInput, MealEntry]):

    def __init__(
        self,
        food_repository:  IFoodRepository,
        entry_repository: IMealEntryRepository,
    ) -> None:
        self._foods   = food_repository
        self._entries = entry_repository

    def execute(self, input_dto: LogMealInput) -> MealEntry:
        if input_dto.quantity_g <= 0:
            raise ValidationError("La cantidad debe ser mayor que 0 g.")
        if input_dto.quantity_g > 5000:
            raise ValidationError("La cantidad no puede superar los 5.000 g.")

        food = self._foods.find_by_id(input_dto.food_id)
        if food is None:
            raise EntityNotFoundError(
                f"Alimento con id {input_dto.food_id} no encontrado."
            )

        entry = MealEntry(
            user_id    = input_dto.user_id,
            food_item  = food,
            meal_type  = input_dto.meal_type,
            quantity_g = input_dto.quantity_g,
            logged_at  = input_dto.logged_at,
        )
        return self._entries.save(entry)


class DeleteMealEntryUseCase(UseCase[DeleteMealEntryInput, None]):

    def __init__(self, entry_repository: IMealEntryRepository) -> None:
        self._entries = entry_repository

    def execute(self, input_dto: DeleteMealEntryInput) -> None:
        entry = self._entries.find_by_id(input_dto.entry_id)
        if entry is None:
            raise EntityNotFoundError(
                f"Entrada {input_dto.entry_id} no encontrada."
            )
        # Business rule: only the owner can delete their entry.
        if entry.user_id != input_dto.user_id:
            from core.exceptions import UnauthorizedError
            raise UnauthorizedError("No tienes permiso para borrar esta entrada.")

        self._entries.delete(input_dto.entry_id)


class MoveMealEntryUseCase(UseCase[MoveMealEntryInput, MealEntry]):
    """Moves/reorders an entry within or between meals of the same day (drag & drop).

    Places the entry in `meal_type` at index `position` and renumbers that meal's
    positions so they stay consecutive.
    """

    def __init__(self, entry_repository: IMealEntryRepository) -> None:
        self._entries = entry_repository

    def execute(self, input_dto: MoveMealEntryInput) -> MealEntry:
        entry = self._entries.find_by_id(input_dto.entry_id)
        if entry is None:
            raise EntityNotFoundError(f"Entrada {input_dto.entry_id} no encontrada.")
        if entry.user_id != input_dto.user_id:
            from core.exceptions import UnauthorizedError
            raise UnauthorizedError("No tienes permiso para mover esta entrada.")

        # Entries of the destination meal (in order), excluding the one we're moving.
        day = self._entries.find_by_user_and_date(entry.user_id, entry.logged_at)
        target_ids = [
            e.id for e in day
            if e.meal_type == input_dto.meal_type and e.id != entry.id
        ]

        idx = input_dto.position if input_dto.position is not None else len(target_ids)
        idx = max(0, min(idx, len(target_ids)))
        target_ids.insert(idx, entry.id)

        self._entries.apply_meal_order(target_ids, input_dto.meal_type)

        moved = self._entries.find_by_id(entry.id)
        return moved if moved is not None else entry


class GetDailyLogUseCase(UseCase[GetDailyLogInput, DailyNutritionLog]):

    def __init__(self, entry_repository: IMealEntryRepository) -> None:
        self._entries = entry_repository

    def execute(self, input_dto: GetDailyLogInput) -> DailyNutritionLog:
        entries = self._entries.find_by_user_and_date(
            input_dto.user_id,
            input_dto.log_date,
        )
        return DailyNutritionLog(
            date    = input_dto.log_date,
            user_id = input_dto.user_id,
            entries = entries,
        )


class GetRecentFoodsUseCase(UseCase[GetRecentFoodsInput, list[FoodItem]]):

    def __init__(self, entry_repository: IMealEntryRepository) -> None:
        self._entries = entry_repository

    def execute(self, input_dto: GetRecentFoodsInput) -> list[FoodItem]:
        return self._entries.find_recent_foods(input_dto.user_id, input_dto.limit)


class GetMonthlySummaryUseCase(UseCase[GetMonthlySummaryInput, dict[str, float]]):
    """Monthly summary: total kcal per day (for the dashboard calendar)."""

    def __init__(self, entry_repository: IMealEntryRepository) -> None:
        self._entries = entry_repository

    def execute(self, input_dto: GetMonthlySummaryInput) -> dict[str, float]:
        if not (1 <= input_dto.month <= 12):
            raise ValidationError("Mes no válido.")
        return self._entries.daily_kcal_for_month(
            input_dto.user_id, input_dto.year, input_dto.month,
        )
