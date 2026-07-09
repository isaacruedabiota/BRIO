from rest_framework import serializers

from apps.nutrition.domain.entities import MealType


class FoodItemSerializer(serializers.Serializer):
    id               = serializers.IntegerField()
    name             = serializers.CharField()
    brand            = serializers.CharField(allow_null=True)
    barcode          = serializers.CharField(allow_null=True)
    kcal_per_100g    = serializers.FloatField()
    protein_per_100g = serializers.FloatField()
    carbs_per_100g   = serializers.FloatField()
    fat_per_100g     = serializers.FloatField()
    fiber_per_100g   = serializers.FloatField()
    source           = serializers.CharField()
    verified         = serializers.BooleanField()
    created_by_id    = serializers.IntegerField(allow_null=True, required=False)


class CreateFoodSerializer(serializers.Serializer):
    name             = serializers.CharField(max_length=255)
    brand            = serializers.CharField(max_length=255, required=False, allow_blank=True, allow_null=True)
    kcal_per_100g    = serializers.FloatField(min_value=0, max_value=900)
    protein_per_100g = serializers.FloatField(min_value=0, max_value=100)
    carbs_per_100g   = serializers.FloatField(min_value=0, max_value=100)
    fat_per_100g     = serializers.FloatField(min_value=0, max_value=100)
    fiber_per_100g   = serializers.FloatField(min_value=0, max_value=100, required=False, default=0.0)


class MacrosSerializer(serializers.Serializer):
    kcal      = serializers.FloatField()
    protein_g = serializers.FloatField()
    carbs_g   = serializers.FloatField()
    fat_g     = serializers.FloatField()
    fiber_g   = serializers.FloatField()


class MealEntrySerializer(serializers.Serializer):
    id         = serializers.IntegerField()
    food_item  = FoodItemSerializer()
    meal_type  = serializers.CharField()
    quantity_g = serializers.FloatField()
    logged_at  = serializers.DateField()
    macros     = MacrosSerializer()

    def to_representation(self, entry):
        return {
            "id":         entry.id,
            "food_item":  FoodItemSerializer(entry.food_item).data,
            "meal_type":  entry.meal_type.value,
            "quantity_g": entry.quantity_g,
            "position":   entry.position,
            "logged_at":  str(entry.logged_at),
            "macros":     MacrosSerializer(entry.macros).data,
        }


class LogMealSerializer(serializers.Serializer):
    food_id    = serializers.IntegerField()
    meal_type  = serializers.ChoiceField(choices=[m.value for m in MealType])
    quantity_g = serializers.FloatField(min_value=0.1, max_value=5000)
    logged_at  = serializers.DateField()


class DailyLogMealSerializer(serializers.Serializer):
    """A meal within the daily log (breakfast, lunch, etc.)."""
    meal_type = serializers.CharField()
    entries   = serializers.ListField()
    totals    = MacrosSerializer()

    def to_representation(self, data):
        return data


class DailyLogSerializer(serializers.Serializer):

    def to_representation(self, log):
        meals = []
        for meal_type in MealType:
            entries = log.by_meal[meal_type]
            meals.append({
                "meal_type": meal_type.value,
                "entries":   [MealEntrySerializer().to_representation(e) for e in entries],
                "totals":    MacrosSerializer(log.meal_totals(meal_type)).data,
            })
        return {
            "date":   str(log.date),
            "totals": MacrosSerializer(log.totals).data,
            "meals":  meals,
        }
