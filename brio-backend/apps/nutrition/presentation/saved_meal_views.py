"""
Saved-meal endpoints (recipes the user reuses).
They can be created from a list of foods or by copying a meal from a day, and
"applied" (adding all their foods to a meal of the day).
"""
from datetime import date

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.nutrition.domain.entities import MealType
from apps.nutrition.infrastructure.models import (
    MealEntryModel,
    SavedMealItemModel,
    SavedMealModel,
)
from apps.nutrition.presentation.serializers import FoodItemSerializer

_VALID_MEALS = {m.value for m in MealType}


def _macros(food, qty_g: float) -> dict:
    f = qty_g / 100
    return {
        "kcal":      round(food.kcal_per_100g * f, 1),
        "protein_g": round(food.protein_per_100g * f, 1),
        "carbs_g":   round(food.carbs_per_100g * f, 1),
        "fat_g":     round(food.fat_per_100g * f, 1),
        "fiber_g":   round(food.fiber_per_100g * f, 1),
    }


def _serialize(meal: SavedMealModel) -> dict:
    items, totals = [], {"kcal": 0, "protein_g": 0, "carbs_g": 0, "fat_g": 0, "fiber_g": 0}
    for it in meal.items.all():
        m = _macros(it.food_item, it.quantity_g)
        items.append({
            "id":         it.id,
            "food_item":  FoodItemSerializer(it.food_item).data,
            "quantity_g": it.quantity_g,
            "macros":     m,
        })
        for k in totals:
            totals[k] += m[k]
    totals = {k: round(v, 1) for k, v in totals.items()}
    return {
        "id":         meal.id,
        "name":       meal.name,
        "items":      items,
        "totals":     totals,
        "item_count": len(items),
    }


class SavedMealListView(APIView):
    """
    GET  /api/nutrition/meals/  → the user's saved meals
    POST /api/nutrition/meals/  → create (with `items` or by copying `from_date`+`from_meal_type`)
    """
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        meals = (SavedMealModel.objects
                 .filter(user=request.user)
                 .prefetch_related("items__food_item"))
        return Response([_serialize(m) for m in meals])

    def post(self, request: Request) -> Response:
        data = request.data
        name = (data.get("name") or "").strip()
        if not name:
            return Response({"detail": "El nombre es obligatorio."}, status=400)

        meal = SavedMealModel.objects.create(user=request.user, name=name)

        items = data.get("items")
        if items:
            # Create from an explicit list of foods.
            for it in items:
                fid, qty = it.get("food_id"), it.get("quantity_g")
                if fid and qty and float(qty) > 0:
                    SavedMealItemModel.objects.create(
                        saved_meal=meal, food_item_id=fid, quantity_g=float(qty))
        else:
            # Create by copying an already-logged meal from a day.
            from_date, from_meal = data.get("from_date"), data.get("from_meal_type")
            if from_date and from_meal:
                try:
                    d = date.fromisoformat(from_date)
                except ValueError:
                    d = None
                if d:
                    entries = MealEntryModel.objects.filter(
                        user=request.user, logged_at=d, meal_type=from_meal)
                    for e in entries:
                        SavedMealItemModel.objects.create(
                            saved_meal=meal, food_item_id=e.food_item_id, quantity_g=e.quantity_g)

        if meal.items.count() == 0:
            meal.delete()
            return Response({"detail": "La comida no tiene alimentos."}, status=400)

        return Response(_serialize(meal), status=status.HTTP_201_CREATED)


class SavedMealDetailView(APIView):
    """DELETE /api/nutrition/meals/{id}/"""
    permission_classes = [IsAuthenticated]

    def delete(self, request: Request, meal_id: int) -> Response:
        SavedMealModel.objects.filter(pk=meal_id, user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class SavedMealLogView(APIView):
    """POST /api/nutrition/meals/{id}/log/  → adds the foods to a meal of the day.
    Body: {"date": "YYYY-MM-DD", "meal_type": "breakfast"}"""
    permission_classes = [IsAuthenticated]

    def post(self, request: Request, meal_id: int) -> Response:
        meal = (SavedMealModel.objects
                .filter(pk=meal_id, user=request.user)
                .prefetch_related("items").first())
        if not meal:
            return Response({"detail": "Comida no encontrada."}, status=404)

        meal_type = request.data.get("meal_type")
        if meal_type not in _VALID_MEALS:
            return Response({"detail": "meal_type inválido."}, status=400)

        raw_date = request.data.get("date")
        try:
            d = date.fromisoformat(raw_date) if raw_date else date.today()
        except ValueError:
            d = date.today()

        created = 0
        for it in meal.items.all():
            MealEntryModel.objects.create(
                user=request.user, food_item_id=it.food_item_id,
                meal_type=meal_type, quantity_g=it.quantity_g, logged_at=d)
            created += 1

        return Response({"created": created}, status=status.HTTP_201_CREATED)
