"""
Food control center (Django admin).

Here the admin reviews user-created (private) foods and decides which ones move
to the shared database (visible to everyone): the "Aprobar a base común" action
sets created_by = None and verified = True.
"""
from django.contrib import admin, messages
from django.utils.html import format_html

from apps.nutrition.infrastructure.models import FoodItemModel


class ScopeFilter(admin.SimpleListFilter):
    """Filters by scope: shared database vs. private pending review."""
    title = "ámbito"
    parameter_name = "scope"

    def lookups(self, request, model_admin):
        return [
            ("pending", "Privados (pendientes de aprobar)"),
            ("common", "Base común"),
        ]

    def queryset(self, request, queryset):
        if self.value() == "pending":
            return queryset.filter(created_by__isnull=False)
        if self.value() == "common":
            return queryset.filter(created_by__isnull=True)
        return queryset


@admin.register(FoodItemModel)
class FoodItemAdmin(admin.ModelAdmin):
    list_display = (
        "name", "brand", "kcal_per_100g", "protein_per_100g",
        "carbs_per_100g", "fat_per_100g", "scope_badge", "verified", "created_at",
    )
    list_filter = (ScopeFilter, "verified", "source")
    search_fields = ("name", "brand", "barcode")
    list_per_page = 50
    ordering = ("-created_at",)
    actions = ("approve_to_common", "reject_custom")
    readonly_fields = ("created_by", "source", "created_at")

    @admin.display(description="ámbito")
    def scope_badge(self, obj: FoodItemModel) -> str:
        if obj.created_by_id is None:
            return format_html('<b style="color:#1B6FD0">Base común</b>')
        return format_html(
            '<span style="color:#A9690B">Privado · {}</span>',
            obj.created_by.email if obj.created_by else "?",
        )

    @admin.action(description="Aprobar a base común (visible para todos)")
    def approve_to_common(self, request, queryset):
        updated = queryset.filter(created_by__isnull=False).update(
            created_by=None, verified=True,
        )
        # Those already in the shared database are just marked as verified.
        also = queryset.filter(created_by__isnull=True, verified=False).update(verified=True)
        self.message_user(
            request,
            f"{updated} alimento(s) aprobado(s) a la base común"
            + (f"; {also} marcado(s) como verificado(s)." if also else "."),
            messages.SUCCESS,
        )

    @admin.action(description="Rechazar (eliminar alimento privado)")
    def reject_custom(self, request, queryset):
        deleted, _ = queryset.filter(created_by__isnull=False).delete()
        self.message_user(
            request, f"{deleted} alimento(s) privado(s) eliminado(s).", messages.WARNING,
        )
