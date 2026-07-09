from django.db import migrations, models


def backfill_positions(apps, schema_editor):
    """Assigns consecutive positions to existing entries, per
    (user, day, meal), respecting creation order."""
    MealEntry = apps.get_model("nutrition", "MealEntryModel")
    from collections import defaultdict

    counters = defaultdict(int)
    qs = MealEntry.objects.order_by("user_id", "logged_at", "meal_type", "created_at")
    to_update = []
    for e in qs:
        key = (e.user_id, e.logged_at, e.meal_type)
        e.position = counters[key]
        counters[key] += 1
        to_update.append(e)
    if to_update:
        MealEntry.objects.bulk_update(to_update, ["position"])


class Migration(migrations.Migration):

    dependencies = [
        ("nutrition", "0004_fooditemmodel_created_by"),
    ]

    operations = [
        migrations.AddField(
            model_name="mealentrymodel",
            name="position",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AlterModelOptions(
            name="mealentrymodel",
            options={"ordering": ["position", "created_at"]},
        ),
        migrations.RunPython(backfill_positions, migrations.RunPython.noop),
    ]
