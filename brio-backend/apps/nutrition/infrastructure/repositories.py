"""
Concrete implementations of the nutrition repositories.

DjangoFoodRepository applies the cache-aside pattern:
  1. Look in the local DB (fast, no cost)
  2. If there are few results, query Open Food Facts and cache them
  3. Return the combined results
"""
from __future__ import annotations

from datetime import date
from typing import Optional

from django.db.models import Max

from apps.nutrition.domain.entities import (
    FoodItem,
    FoodSource,
    MealEntry,
    MealType,
)
from apps.nutrition.domain.repositories import IFoodRepository, IMealEntryRepository
from apps.nutrition.infrastructure.models import FoodItemModel, MealEntryModel
from apps.nutrition.infrastructure.open_food_facts import OpenFoodFactsClient

_LOCAL_THRESHOLD = 5   # if there are fewer local results, supplement with OFF


class DjangoFoodRepository(IFoodRepository):

    def __init__(self, off_client: OpenFoodFactsClient | None = None) -> None:
        self._off = off_client or OpenFoodFactsClient()

    # IFoodRepository.

    def find_by_id(self, entity_id: int) -> Optional[FoodItem]:
        try:
            return self._to_entity(FoodItemModel.objects.get(pk=entity_id))
        except FoodItemModel.DoesNotExist:
            return None

    def find_by_barcode(self, barcode: str) -> Optional[FoodItem]:
        # 1. Local cache.
        try:
            return self._to_entity(FoodItemModel.objects.get(barcode=barcode))
        except FoodItemModel.DoesNotExist:
            pass
        # 2. Open Food Facts.
        food = self._off.get_by_barcode(barcode)
        if food:
            return self.save(food)
        return None

    def search(self, query: str, limit: int = 20, user_id: int | None = None) -> list[FoodItem]:
        from django.db.models import Q

        # 1. Local DB: shared database (created_by NULL) + the user's own foods.
        #    Other users' private foods are never included.
        visible = Q(created_by__isnull=True)
        if user_id is not None:
            visible |= Q(created_by_id=user_id)
        local_qs = (
            FoodItemModel.objects
            .filter(name__icontains=query)
            .filter(visible)
            .order_by("-verified", "name")[:limit]
        )
        local = [self._to_entity(m) for m in local_qs]

        # 2. Supplement with OFF if there are few local results.
        if len(local) < _LOCAL_THRESHOLD:
            off_items = self._off.search(query, limit=limit - len(local))
            new_items = self._cache_off_items(off_items)
            # Avoid duplicates with the local results already found.
            local_ids = {f.id for f in local}
            local += [f for f in new_items if f.id not in local_ids]

        return local[:limit]

    def save(self, entity: FoodItem) -> FoodItem:
        if entity.id is not None:
            FoodItemModel.objects.filter(pk=entity.id).update(
                name             = entity.name,
                brand            = entity.brand,
                kcal_per_100g    = entity.kcal_per_100g,
                protein_per_100g = entity.protein_per_100g,
                carbs_per_100g   = entity.carbs_per_100g,
                fat_per_100g     = entity.fat_per_100g,
                fiber_per_100g   = entity.fiber_per_100g,
                verified         = entity.verified,
            )
            return self._to_entity(FoodItemModel.objects.get(pk=entity.id))

        # Upsert by barcode to avoid OFF duplicates.
        if entity.barcode:
            model, _ = FoodItemModel.objects.get_or_create(
                barcode=entity.barcode,
                defaults=self._to_model_kwargs(entity),
            )
        else:
            model = FoodItemModel.objects.create(**self._to_model_kwargs(entity))
        return self._to_entity(model)

    def save_batch(self, items: list[FoodItem]) -> list[FoodItem]:
        return [self.save(item) for item in items]

    def delete(self, entity_id: int) -> None:
        FoodItemModel.objects.filter(pk=entity_id).delete()

    # Helpers.

    def _cache_off_items(self, items: list[FoodItem]) -> list[FoodItem]:
        return self.save_batch(items)

    @staticmethod
    def _to_model_kwargs(entity: FoodItem) -> dict:
        return {
            "name":             entity.name,
            "brand":            entity.brand,
            "barcode":          entity.barcode,
            "kcal_per_100g":    entity.kcal_per_100g,
            "protein_per_100g": entity.protein_per_100g,
            "carbs_per_100g":   entity.carbs_per_100g,
            "fat_per_100g":     entity.fat_per_100g,
            "fiber_per_100g":   entity.fiber_per_100g,
            "source":           entity.source.value,
            "verified":         entity.verified,
            "created_by_id":    entity.created_by_id,
        }

    @staticmethod
    def _to_entity(model: FoodItemModel) -> FoodItem:
        return FoodItem(
            id               = model.pk,
            name             = model.name,
            brand            = model.brand,
            barcode          = model.barcode,
            kcal_per_100g    = model.kcal_per_100g,
            protein_per_100g = model.protein_per_100g,
            carbs_per_100g   = model.carbs_per_100g,
            fat_per_100g     = model.fat_per_100g,
            fiber_per_100g   = model.fiber_per_100g,
            source           = FoodSource(model.source),
            verified         = model.verified,
            created_by_id    = model.created_by_id,
        )


class DjangoMealEntryRepository(IMealEntryRepository):

    def find_by_id(self, entity_id: int) -> Optional[MealEntry]:
        try:
            model = MealEntryModel.objects.select_related("food_item").get(pk=entity_id)
            return self._to_entity(model)
        except MealEntryModel.DoesNotExist:
            return None

    def find_by_user_and_date(self, user_id: int, log_date: date) -> list[MealEntry]:
        qs = (
            MealEntryModel.objects
            .select_related("food_item")
            .filter(user_id=user_id, logged_at=log_date)
            .order_by("position", "created_at")
        )
        return [self._to_entity(m) for m in qs]

    def apply_meal_order(self, entry_ids: list[int], meal_type) -> None:
        models = {m.pk: m for m in MealEntryModel.objects.filter(pk__in=entry_ids)}
        to_update = []
        for pos, eid in enumerate(entry_ids):
            m = models.get(eid)
            if m is None:
                continue
            m.position  = pos
            m.meal_type = meal_type.value
            to_update.append(m)
        if to_update:
            MealEntryModel.objects.bulk_update(to_update, ["position", "meal_type"])

    def daily_kcal_for_month(
        self, user_id: int, year: int, month: int
    ) -> dict[str, float]:
        from collections import defaultdict
        entries = (
            MealEntryModel.objects
            .select_related("food_item")
            .filter(user_id=user_id, logged_at__year=year, logged_at__month=month)
        )
        totals: dict[str, float] = defaultdict(float)
        for e in entries:
            kcal = e.food_item.kcal_per_100g * e.quantity_g / 100
            totals[e.logged_at.isoformat()] += kcal
        return {day: round(v, 1) for day, v in totals.items()}

    def find_recent_foods(self, user_id: int, limit: int = 15) -> list[FoodItem]:
        # Most recent distinct foods logged by the user.
        subq = (
            MealEntryModel.objects
            .filter(user_id=user_id)
            .values("food_item_id")
            .annotate(last_used=Max("logged_at"))
            .order_by("-last_used")[:limit]
        )
        food_ids = [row["food_item_id"] for row in subq]
        foods    = {f.pk: f for f in FoodItemModel.objects.filter(pk__in=food_ids)}
        return [
            DjangoFoodRepository._to_entity(foods[fid])
            for fid in food_ids
            if fid in foods
        ]

    def save(self, entity: MealEntry) -> MealEntry:
        if entity.id is not None:
            MealEntryModel.objects.filter(pk=entity.id).update(
                quantity_g = entity.quantity_g,
                meal_type  = entity.meal_type.value,
                position   = entity.position,
            )
            model = MealEntryModel.objects.select_related("food_item").get(pk=entity.id)
        else:
            # New entry → goes to the end of its meal (position = max + 1).
            from django.db.models import Max
            last = (
                MealEntryModel.objects
                .filter(user_id=entity.user_id, logged_at=entity.logged_at,
                        meal_type=entity.meal_type.value)
                .aggregate(m=Max("position"))["m"]
            )
            model = MealEntryModel.objects.create(
                user_id     = entity.user_id,
                food_item_id= entity.food_item.id,
                meal_type   = entity.meal_type.value,
                quantity_g  = entity.quantity_g,
                position    = 0 if last is None else last + 1,
                logged_at   = entity.logged_at,
            )
            model = MealEntryModel.objects.select_related("food_item").get(pk=model.pk)
        return self._to_entity(model)

    def delete(self, entity_id: int) -> None:
        MealEntryModel.objects.filter(pk=entity_id).delete()

    @staticmethod
    def _to_entity(model: MealEntryModel) -> MealEntry:
        return MealEntry(
            id         = model.pk,
            user_id    = model.user_id,
            food_item  = DjangoFoodRepository._to_entity(model.food_item),
            meal_type  = MealType(model.meal_type),
            quantity_g = model.quantity_g,
            position   = model.position,
            logged_at  = model.logged_at,
        )
