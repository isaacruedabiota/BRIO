"""
python manage.py seed_exercises
Loads the base exercises into the DB. Idempotent (get_or_create).
"""
from django.core.management.base import BaseCommand

from apps.training.infrastructure.models import ExerciseModel

EXERCISES = [
    # Chest.
    ("Press de banca",               ["chest","triceps","shoulders"], "barbell"),
    ("Press de banca inclinado",     ["chest","triceps","shoulders"], "barbell"),
    ("Press de banca con mancuernas",["chest","triceps","shoulders"], "dumbbell"),
    ("Aperturas con mancuernas",     ["chest"],                       "dumbbell"),
    ("Fondos en paralelas",          ["chest","triceps"],             "bodyweight"),
    ("Cruces en polea",              ["chest"],                       "cable"),
    # Back.
    ("Peso muerto",                  ["back","hamstrings","glutes"],  "barbell"),
    ("Dominadas",                    ["back","biceps"],               "bodyweight"),
    ("Remo con barra",               ["back","biceps"],               "barbell"),
    ("Remo con mancuerna",           ["back","biceps"],               "dumbbell"),
    ("Jalón al pecho",               ["back","biceps"],               "cable"),
    ("Remo en polea baja",           ["back","biceps"],               "cable"),
    # Shoulders.
    ("Press militar con barra",      ["shoulders","triceps"],         "barbell"),
    ("Press de hombros mancuernas",  ["shoulders","triceps"],         "dumbbell"),
    ("Elevaciones laterales",        ["shoulders"],                   "dumbbell"),
    ("Elevaciones frontales",        ["shoulders"],                   "dumbbell"),
    ("Face pulls",                   ["shoulders","back"],            "cable"),
    # Legs.
    ("Sentadilla con barra",         ["quads","glutes","core"],       "barbell"),
    ("Sentadilla frontal",           ["quads","glutes","core"],       "barbell"),
    ("Prensa de pierna",             ["quads","glutes","hamstrings"], "machine"),
    ("Extensión de cuádriceps",      ["quads"],                       "machine"),
    ("Curl femoral tumbado",         ["hamstrings"],                  "machine"),
    ("Peso muerto rumano",           ["hamstrings","glutes"],         "barbell"),
    ("Hip thrust",                   ["glutes","hamstrings"],         "barbell"),
    ("Zancadas",                     ["quads","glutes"],              "dumbbell"),
    ("Elevación de gemelos de pie",  ["calves"],                      "machine"),
    # Biceps.
    ("Curl de bíceps con barra",     ["biceps"],                      "barbell"),
    ("Curl con mancuernas alterno",  ["biceps"],                      "dumbbell"),
    ("Curl martillo",                ["biceps","forearms"],           "dumbbell"),
    ("Curl en polea baja",           ["biceps"],                      "cable"),
    # Triceps.
    ("Press francés",                ["triceps"],                     "barbell"),
    ("Extensión de tríceps polea",   ["triceps"],                     "cable"),
    ("Patada de tríceps",            ["triceps"],                     "dumbbell"),
    # Core.
    ("Plancha",                      ["core"],                        "bodyweight"),
    ("Crunch abdominal",             ["core"],                        "bodyweight"),
    ("Rueda abdominal",              ["core"],                        "other"),
]


class Command(BaseCommand):
    help = "Carga los ejercicios base en la BD (idempotente)"

    def handle(self, *args, **options):
        created = 0
        for name, muscle_groups, equipment in EXERCISES:
            _, was_created = ExerciseModel.objects.get_or_create(
                name=name,
                defaults={
                    "muscle_groups": muscle_groups,
                    "equipment":     equipment,
                    "is_custom":     False,
                },
            )
            if was_created:
                created += 1

        total = ExerciseModel.objects.count()
        self.stdout.write(
            self.style.SUCCESS(
                f"OK: {created} ejercicios creados | {total} total en BD"
            )
        )
