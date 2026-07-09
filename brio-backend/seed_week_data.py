"""
Populates the current week with realistic data for carlos2@brio.app:
varied meals each day + workout sessions with sets and PRs.

Usage:  .\venv\Scripts\python seed_week_data.py
Idempotent: deletes the week's data before reinserting.
"""
import os
import random
from datetime import date, datetime, time, timedelta, timezone

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")
django.setup()

from apps.users.infrastructure.models import UserModel
from apps.nutrition.infrastructure.models import FoodItemModel, MealEntryModel
from apps.training.infrastructure.models import (
    ExerciseModel, RoutineModel, RoutineExerciseModel,
    WorkoutSessionModel, WorkoutSetModel,
)

random.seed(42)

user = UserModel.objects.get(email="carlos2@brio.app")

# 1. Foods (per 100 g).
FOODS = {
    "Avena en copos":            (389, 13.0, 66.0, 7.0),
    "Leche semidesnatada":       (47,  3.3,  4.8, 1.6),
    "Plátano":                   (89,  1.1, 23.0, 0.3),
    "Huevo":                     (155, 13.0, 1.1, 11.0),
    "Pechuga de pollo":          (165, 31.0, 0.0, 3.6),
    "Arroz blanco cocido":       (130, 2.7, 28.0, 0.3),
    "Aceite de oliva virgen":    (884, 0.0,  0.0, 100.0),
    "Atún al natural":           (116, 26.0, 0.0, 1.0),
    "Yogur griego natural":      (59, 10.0,  3.6, 0.4),
    "Almendras":                 (579, 21.0, 22.0, 49.0),
    "Pan integral":              (247, 13.0, 41.0, 3.4),
    "Salmón":                    (208, 20.0, 0.0, 13.0),
    "Pasta cocida":              (158, 5.8, 31.0, 0.9),
    "Patata cocida":             (77,  2.0, 17.0, 0.1),
    "Lentejas cocidas":          (116, 9.0, 20.0, 0.4),
    "Tomate":                    (18,  0.9, 3.9, 0.2),
    "Queso fresco batido":       (72, 12.0, 4.0, 0.2),
    "Manzana":                   (52,  0.3, 14.0, 0.2),
}

food_objs = {}
for name, (kcal, p, c, f) in FOODS.items():
    obj, _ = FoodItemModel.objects.get_or_create(
        name=name,
        defaults=dict(
            kcal_per_100g=kcal, protein_per_100g=p,
            carbs_per_100g=c, fat_per_100g=f,
            source="manual", verified=True,
        ),
    )
    food_objs[name] = obj

# 2. Routines (Push A already exists; we create Pull A and Legs).
def ensure_routine(name, exercise_specs):
    routine = RoutineModel.objects.filter(user=user, name=name).first()
    if routine is None:
        routine = RoutineModel.objects.create(user=user, name=name)
        for order, (ex_name, sets, reps) in enumerate(exercise_specs):
            ex = ExerciseModel.objects.filter(name=ex_name).first()
            if ex:
                RoutineExerciseModel.objects.create(
                    routine=routine, exercise=ex, sets=sets, reps=reps,
                    rest_seconds=90, order=order,
                )
    return routine

push = ensure_routine("Push A", [
    ("Press de banca", 4, 8), ("Press militar con barra", 3, 10),
    ("Fondos en paralelas", 3, 12), ("Extensión de tríceps polea", 3, 15),
])
pull = ensure_routine("Pull A", [
    ("Dominadas", 4, 8), ("Remo con barra", 4, 10),
    ("Jalón al pecho", 3, 12), ("Curl de bíceps con barra", 3, 12),
])
legs = ensure_routine("Legs", [
    ("Sentadilla con barra", 5, 5), ("Prensa de pierna", 4, 12),
    ("Curl femoral tumbado", 3, 12), ("Elevación de gemelos de pie", 4, 15),
])

# 3. Current week (Monday → today).
today = date(2026, 5, 31)            # Sunday
monday = today - timedelta(days=today.weekday())
week = [monday + timedelta(days=i) for i in range(7)]

# Clear the week's previous data (idempotency).
MealEntryModel.objects.filter(user=user, logged_at__gte=monday, logged_at__lte=today).delete()
WorkoutSessionModel.objects.filter(user=user, started_at__date__gte=monday).delete()

def add_meal(day, meal_type, items):
    """items = [(food_name, grams), ...]"""
    for name, grams in items:
        MealEntryModel.objects.create(
            user=user, food_item=food_objs[name],
            meal_type=meal_type, quantity_g=grams, logged_at=day,
        )

def jitter(g, pct=0.18):
    return round(g * (1 + random.uniform(-pct, pct)))

# Meal templates (base grams) — varied each day with jitter.
for i, day in enumerate(week):
    is_today = day == today

    # Breakfast.
    add_meal(day, "breakfast", [
        ("Avena en copos", jitter(80)),
        ("Leche semidesnatada", jitter(250)),
        ("Plátano", jitter(120)),
        ("Huevo", jitter(120)),  # ~2 eggs
    ])
    if is_today:
        # today: breakfast only (day in progress)
        continue

    # Lunch.
    add_meal(day, "lunch", [
        ("Pechuga de pollo", jitter(220)),
        ("Arroz blanco cocido", jitter(240)),
        ("Aceite de oliva virgen", jitter(12)),
        ("Tomate", jitter(100)),
    ])

    # Post-workout snack.
    add_meal(day, "snack", [
        ("Yogur griego natural", jitter(200)),
        ("Almendras", jitter(30)),
        ("Manzana", jitter(150)),
    ])

    # Dinner (alternates salmon / pasta+tuna / lentils).
    if i % 3 == 0:
        add_meal(day, "dinner", [
            ("Salmón", jitter(200)), ("Patata cocida", jitter(250)),
            ("Aceite de oliva virgen", jitter(8)),
        ])
    elif i % 3 == 1:
        add_meal(day, "dinner", [
            ("Pasta cocida", jitter(250)), ("Atún al natural", jitter(120)),
            ("Tomate", jitter(80)),
        ])
    else:
        add_meal(day, "dinner", [
            ("Lentejas cocidas", jitter(300)), ("Pan integral", jitter(60)),
            ("Queso fresco batido", jitter(150)),
        ])

# 4. Workouts of the week.
# (day_idx, routine, [(exercise, [(reps, weight, is_pr), ...]), ...])
def make_session(day, routine, blocks, start_hour=18, dur_min=58):
    started  = datetime.combine(day, time(start_hour, 0), tzinfo=timezone.utc)
    finished = started + timedelta(minutes=dur_min)
    session = WorkoutSessionModel.objects.create(
        user=user, routine=routine, started_at=started,
        finished_at=finished, notes="",
    )
    for ex_name, sets in blocks:
        ex = ExerciseModel.objects.filter(name=ex_name).first()
        if not ex:
            continue
        for n, (reps, weight, is_pr) in enumerate(sets, start=1):
            WorkoutSetModel.objects.create(
                session=session, exercise=ex, reps=reps, weight_kg=weight,
                set_number=n, rpe=min(10, 6 + n), is_warmup=False, is_pr=is_pr,
            )

# Monday – Push.
make_session(week[0], push, [
    ("Press de banca",          [(8, 80, False), (8, 82.5, False), (6, 85, True)]),
    ("Press militar con barra", [(10, 45, False), (9, 47.5, False)]),
    ("Fondos en paralelas",     [(12, 0, False), (12, 0, False)]),
])
# Tuesday – Pull.
make_session(week[1], pull, [
    ("Dominadas",               [(8, 0, False), (8, 5, True), (6, 5, False)]),
    ("Remo con barra",          [(10, 70, False), (10, 72.5, False)]),
    ("Curl de bíceps con barra",[(12, 30, False), (10, 32.5, False)]),
])
# Wednesday – Legs.
make_session(week[2], legs, [
    ("Sentadilla con barra",    [(5, 100, False), (5, 105, False), (5, 110, True)]),
    ("Prensa de pierna",        [(12, 180, False), (12, 190, False)]),
    ("Curl femoral tumbado",    [(12, 40, False), (12, 42.5, False)]),
])
# Thursday – Push (more volume).
make_session(week[3], push, [
    ("Press de banca",          [(8, 82.5, False), (8, 85, False), (7, 87.5, True)]),
    ("Press militar con barra", [(10, 47.5, False), (10, 50, True)]),
    ("Fondos en paralelas",     [(12, 5, False), (10, 10, False)]),
])
# Friday – Pull.
make_session(week[4], pull, [
    ("Dominadas",               [(8, 7.5, True), (7, 7.5, False)]),
    ("Jalón al pecho",          [(12, 60, False), (12, 65, False)]),
    ("Remo con barra",          [(10, 75, True), (9, 75, False)]),
])
# Saturday – Legs.
make_session(week[5], legs, [
    ("Sentadilla con barra",    [(5, 110, False), (5, 112.5, True), (4, 115, False)]),
    ("Prensa de pierna",        [(12, 190, False), (12, 200, True)]),
    ("Elevación de gemelos de pie", [(15, 80, False), (15, 85, False)]),
])
# Sunday (today) – rest.

# Summary.
meals = MealEntryModel.objects.filter(user=user, logged_at__gte=monday).count()
sessions = WorkoutSessionModel.objects.filter(user=user, started_at__date__gte=monday).count()
sets_total = WorkoutSetModel.objects.filter(session__user=user, session__started_at__date__gte=monday).count()
print(f"OK semana {monday} - {today}")
print(f"  Comidas registradas: {meals}")
print(f"  Sesiones de entreno: {sessions}")
print(f"  Series totales:      {sets_total}")
