from django.urls import path

from apps.nutrition.presentation.views import (
    FoodBarcodeView,
    FoodCreateView,
    FoodSearchView,
    MealEntryDetailView,
    MealEntryListView,
    MonthlySummaryView,
    RecentFoodsView,
)
from apps.nutrition.presentation.saved_meal_views import (
    SavedMealDetailView,
    SavedMealListView,
    SavedMealLogView,
)

urlpatterns = [
    path("foods/search/",            FoodSearchView.as_view(),      name="food-search"),
    path("foods/",                   FoodCreateView.as_view(),      name="food-create"),
    path("foods/recent/",            RecentFoodsView.as_view(),     name="food-recent"),
    path("foods/barcode/<str:barcode>/", FoodBarcodeView.as_view(), name="food-barcode"),
    path("entries/",                 MealEntryListView.as_view(),   name="meal-entries"),
    path("entries/<int:entry_id>/",  MealEntryDetailView.as_view(), name="meal-entry-detail"),
    path("monthly-summary/",         MonthlySummaryView.as_view(),  name="monthly-summary"),
    # Comidas guardadas
    path("meals/",                   SavedMealListView.as_view(),   name="saved-meals"),
    path("meals/<int:meal_id>/",     SavedMealDetailView.as_view(), name="saved-meal-detail"),
    path("meals/<int:meal_id>/log/", SavedMealLogView.as_view(),    name="saved-meal-log"),
]
