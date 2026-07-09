from datetime import date

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.nutrition.application.use_cases import (
    CreateFoodInput,
    CreateFoodUseCase,
    DeleteMealEntryInput,
    DeleteMealEntryUseCase,
    GetDailyLogInput,
    GetDailyLogUseCase,
    GetMonthlySummaryInput,
    GetMonthlySummaryUseCase,
    GetRecentFoodsInput,
    GetRecentFoodsUseCase,
    GetFoodByBarcodeInput,
    GetFoodByBarcodeUseCase,
    LogMealInput,
    LogMealUseCase,
    MoveMealEntryInput,
    MoveMealEntryUseCase,
    SearchFoodInput,
    SearchFoodUseCase,
)
from apps.nutrition.domain.entities import MealType
from apps.nutrition.infrastructure.repositories import (
    DjangoFoodRepository,
    DjangoMealEntryRepository,
)
from apps.nutrition.presentation.serializers import (
    CreateFoodSerializer,
    DailyLogSerializer,
    FoodItemSerializer,
    LogMealSerializer,
    MealEntrySerializer,
)
from core.exceptions import (
    EntityNotFoundError,
    UnauthorizedError,
    ValidationError,
)


def _deps():
    foods   = DjangoFoodRepository()
    entries = DjangoMealEntryRepository()
    return foods, entries


def _targets_for(user_id: int, log_date: date) -> dict | None:
    """Macro target in effect on `log_date` (historized). Falls back to the
    current profile if there's no history yet."""
    from apps.users.infrastructure.models import (
        MacroTargetHistoryModel,
        UserProfileModel,
    )

    row = MacroTargetHistoryModel.applicable_for(user_id, log_date)
    if row is not None:
        return {
            "kcal":      row.daily_kcal_target,
            "protein_g": row.protein_g_target,
            "carbs_g":   row.carbs_g_target,
            "fat_g":     row.fat_g_target,
        }
    profile = UserProfileModel.objects.filter(user_id=user_id).first()
    if profile is None:
        return None
    return {
        "kcal":      profile.daily_kcal_target,
        "protein_g": profile.protein_g_target,
        "carbs_g":   profile.carbs_g_target,
        "fat_g":     profile.fat_g_target,
    }


class FoodSearchView(APIView):
    """GET /api/nutrition/foods/search/?q=tortilla&limit=20"""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        query = request.query_params.get("q", "").strip()
        limit = min(int(request.query_params.get("limit", 20)), 50)

        foods, _ = _deps()
        try:
            results = SearchFoodUseCase(foods).execute(
                SearchFoodInput(query=query, limit=limit, user_id=request.user.pk)
            )
        except ValidationError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(FoodItemSerializer(results, many=True).data)


class FoodCreateView(APIView):
    """POST /api/nutrition/foods/  → creates a user's private food."""
    permission_classes = [IsAuthenticated]

    def post(self, request: Request) -> Response:
        serializer = CreateFoodSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        foods, _ = _deps()
        try:
            food = CreateFoodUseCase(foods).execute(
                CreateFoodInput(
                    user_id          = request.user.pk,
                    name             = data["name"],
                    brand            = data.get("brand"),
                    kcal_per_100g    = data["kcal_per_100g"],
                    protein_per_100g = data["protein_per_100g"],
                    carbs_per_100g   = data["carbs_per_100g"],
                    fat_per_100g     = data["fat_per_100g"],
                    fiber_per_100g   = data.get("fiber_per_100g", 0.0),
                )
            )
        except ValidationError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(FoodItemSerializer(food).data, status=status.HTTP_201_CREATED)


class FoodBarcodeView(APIView):
    """GET /api/nutrition/foods/barcode/{barcode}/"""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request, barcode: str) -> Response:
        foods, _ = _deps()
        try:
            food = GetFoodByBarcodeUseCase(foods).execute(
                GetFoodByBarcodeInput(barcode=barcode)
            )
        except EntityNotFoundError as e:
            return Response({"detail": str(e)}, status=status.HTTP_404_NOT_FOUND)

        return Response(FoodItemSerializer(food).data)


class MealEntryListView(APIView):
    """
    GET  /api/nutrition/entries/?date=2026-05-28  → full daily log
    POST /api/nutrition/entries/                  → add an entry
    """
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        raw_date = request.query_params.get("date", str(date.today()))
        try:
            log_date = date.fromisoformat(raw_date)
        except ValueError:
            return Response({"detail": "Formato de fecha inválido. Usa YYYY-MM-DD."}, status=400)

        _, entries = _deps()
        log = GetDailyLogUseCase(entries).execute(
            GetDailyLogInput(user_id=request.user.pk, log_date=log_date)
        )
        data = DailyLogSerializer().to_representation(log)
        data["targets"] = _targets_for(request.user.pk, log_date)
        return Response(data)

    def post(self, request: Request) -> Response:
        serializer = LogMealSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        foods, entries = _deps()
        try:
            entry = LogMealUseCase(foods, entries).execute(
                LogMealInput(
                    user_id    = request.user.pk,
                    food_id    = data["food_id"],
                    meal_type  = MealType(data["meal_type"]),
                    quantity_g = data["quantity_g"],
                    logged_at  = data["logged_at"],
                )
            )
        except (EntityNotFoundError, ValidationError) as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(
            MealEntrySerializer().to_representation(entry),
            status=status.HTTP_201_CREATED,
        )


class MealEntryDetailView(APIView):
    """
    PATCH  /api/nutrition/entries/{id}/  → moves the entry to another meal
    DELETE /api/nutrition/entries/{id}/
    """
    permission_classes = [IsAuthenticated]

    def patch(self, request: Request, entry_id: int) -> Response:
        raw = request.data.get("meal_type")
        try:
            meal_type = MealType(raw)
        except ValueError:
            return Response({"detail": "meal_type no válido."}, status=status.HTTP_400_BAD_REQUEST)

        position = request.data.get("position")
        try:
            position = int(position) if position is not None else None
        except (TypeError, ValueError):
            position = None

        _, entries = _deps()
        try:
            entry = MoveMealEntryUseCase(entries).execute(
                MoveMealEntryInput(
                    entry_id=entry_id, user_id=request.user.pk,
                    meal_type=meal_type, position=position,
                )
            )
        except EntityNotFoundError as e:
            return Response({"detail": str(e)}, status=status.HTTP_404_NOT_FOUND)
        except UnauthorizedError as e:
            return Response({"detail": str(e)}, status=status.HTTP_403_FORBIDDEN)

        return Response(MealEntrySerializer().to_representation(entry))

    def delete(self, request: Request, entry_id: int) -> Response:
        _, entries = _deps()
        try:
            DeleteMealEntryUseCase(entries).execute(
                DeleteMealEntryInput(entry_id=entry_id, user_id=request.user.pk)
            )
        except EntityNotFoundError as e:
            return Response({"detail": str(e)}, status=status.HTTP_404_NOT_FOUND)
        except UnauthorizedError as e:
            return Response({"detail": str(e)}, status=status.HTTP_403_FORBIDDEN)

        return Response(status=status.HTTP_204_NO_CONTENT)


class RecentFoodsView(APIView):
    """GET /api/nutrition/foods/recent/"""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        _, entries = _deps()
        foods = GetRecentFoodsUseCase(entries).execute(
            GetRecentFoodsInput(user_id=request.user.pk)
        )
        return Response(FoodItemSerializer(foods, many=True).data)


class MonthlySummaryView(APIView):
    """GET /api/nutrition/monthly-summary/?year=2026&month=5"""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        from datetime import date
        today = date.today()
        year  = int(request.query_params.get("year", today.year))
        month = int(request.query_params.get("month", today.month))

        _, entries = _deps()
        try:
            data = GetMonthlySummaryUseCase(entries).execute(
                GetMonthlySummaryInput(user_id=request.user.pk, year=year, month=month)
            )
        except ValidationError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(data)
