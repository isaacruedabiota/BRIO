from django.db import models

from apps.nutrition.domain.entities import FoodSource, MealType
from apps.users.infrastructure.models import UserModel


class FoodItemModel(models.Model):
    name             = models.CharField(max_length=255, db_index=True)
    brand            = models.CharField(max_length=255, blank=True, null=True)
    barcode          = models.CharField(max_length=50, unique=True, blank=True, null=True, db_index=True)
    kcal_per_100g    = models.FloatField()
    protein_per_100g = models.FloatField()
    carbs_per_100g   = models.FloatField()
    fat_per_100g     = models.FloatField()
    fiber_per_100g   = models.FloatField(default=0.0)
    source           = models.CharField(
        max_length=20,
        choices=[(s.value, s.name) for s in FoodSource],
        default=FoodSource.MANUAL.value,
    )
    verified         = models.BooleanField(default=False)
    # None = food from the shared database (visible to everyone). If it points to
    # a user, it's a private food only its creator sees until the admin approves
    # it to the shared database (created_by -> None, verified -> True).
    created_by       = models.ForeignKey(
        UserModel,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="custom_foods",
        db_index=True,
    )
    created_at       = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "food_items"
        indexes  = [models.Index(fields=["name"])]

    def __str__(self) -> str:
        return self.name


class MealEntryModel(models.Model):
    user       = models.ForeignKey(UserModel, on_delete=models.CASCADE, related_name="meal_entries")
    food_item  = models.ForeignKey(FoodItemModel, on_delete=models.PROTECT)
    meal_type  = models.CharField(max_length=20, choices=[(m.value, m.name) for m in MealType])
    quantity_g = models.FloatField()
    # Order of the entry within its meal (for drag & drop reordering).
    position   = models.PositiveIntegerField(default=0)
    logged_at  = models.DateField(db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "meal_entries"
        ordering = ["position", "created_at"]
        indexes  = [models.Index(fields=["user", "logged_at"])]

    def __str__(self) -> str:
        return f"{self.user.email} — {self.food_item.name} ({self.logged_at})"


class SavedMealModel(models.Model):
    """A meal saved by the user (e.g. 'Desayuno típico')."""
    user       = models.ForeignKey(UserModel, on_delete=models.CASCADE, related_name="saved_meals")
    name       = models.CharField(max_length=200)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "saved_meals"
        ordering = ["name"]

    def __str__(self) -> str:
        return f"{self.user.email} — {self.name}"


class SavedMealItemModel(models.Model):
    """A food (with its quantity) inside a saved meal."""
    saved_meal = models.ForeignKey(SavedMealModel, on_delete=models.CASCADE, related_name="items")
    food_item  = models.ForeignKey(FoodItemModel, on_delete=models.PROTECT)
    quantity_g = models.FloatField()

    class Meta:
        db_table = "saved_meal_items"

    def __str__(self) -> str:
        return f"{self.saved_meal.name} — {self.food_item.name} ({self.quantity_g} g)"
