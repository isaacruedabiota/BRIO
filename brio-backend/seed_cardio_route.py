"""
Seeds a cardio activity (running) for carlos2@brio.app on 2026-06-11 with a
made-up GPS route: a loop around Parque del Retiro (Madrid).

Usage:  venv\\Scripts\\python.exe seed_cardio_route.py
Idempotent: deletes that day's 'running' activity before recreating it.
"""
import os
import math
import random
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")
django.setup()

from datetime import date

from django.contrib.auth import get_user_model

from apps.training.domain.activities import calories_for, met_for
from apps.training.infrastructure.models import ActivityLogModel

EMAIL = "carlos2@brio.app"
WHEN = date(2026, 6, 11)
ACTIVITY = "running"

# Waypoints (lat, lng) tracing a loop around Parque del Retiro, Madrid.
WAYPOINTS = [
    (40.4195, -3.6885), (40.4198, -3.6850), (40.4193, -3.6818),
    (40.4183, -3.6800), (40.4168, -3.6788), (40.4150, -3.6782),
    (40.4128, -3.6782), (40.4108, -3.6790), (40.4090, -3.6802),
    (40.4072, -3.6818), (40.4062, -3.6840), (40.4060, -3.6862),
    (40.4068, -3.6882), (40.4082, -3.6896), (40.4100, -3.6902),
    (40.4120, -3.6902), (40.4140, -3.6900), (40.4160, -3.6898),
    (40.4178, -3.6894), (40.4195, -3.6885),  # closes the loop
]


def haversine_m(a, b):
    """Distance in meters between two (lat, lng)."""
    r = 6371000.0
    lat1, lon1, lat2, lon2 = map(math.radians, [a[0], a[1], b[0], b[1]])
    dlat, dlon = lat2 - lat1, lon2 - lon1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def densify(points, steps=8):
    """Interpolates `steps` points between each pair for a smooth polyline."""
    out = []
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        for s in range(steps):
            t = s / steps
            out.append([
                round(a[0] + (b[0] - a[0]) * t, 6),
                round(a[1] + (b[1] - a[1]) * t, 6),
            ])
    out.append([round(points[-1][0], 6), round(points[-1][1], 6)])
    return out


# Football (field sport) → point cloud for a heat map.
FOOTBALL_KEY = "football"
# Center of a football field (Madrid). Dimensions ~100 x 64 m.
FIELD_CENTER = (40.45300, -3.68830)
FIELD_LEN_M = 100.0   # E-W (length)
FIELD_WID_M = 64.0    # N-S (width)


def _m_to_deg(lat, dlat_m, dlng_m):
    return (
        dlat_m / 111320.0,
        dlng_m / (111320.0 * math.cos(math.radians(lat))),
    )


def football_heatmap_points(n=260, seed=42):
    """Generates positions within the field: the player covers the whole pitch
    but spends most of the time in their zone (center-right, wing)."""
    rng = random.Random(seed)
    clat, clng = FIELD_CENTER
    half_lat, half_lng = _m_to_deg(clat, FIELD_WID_M / 2, FIELD_LEN_M / 2)
    # Player's main zone: to the right (+lng) and slightly up.
    zlat, zlng = _m_to_deg(clat, 10.0, 22.0)   # hot-zone offset
    s_lat, s_lng = _m_to_deg(clat, 13.0, 18.0)  # sigma of the main cloud

    pts = []
    for _ in range(n):
        if rng.random() < 0.72:
            # Gaussian cloud in the main zone.
            lat = clat + zlat + rng.gauss(0, s_lat)
            lng = clng + zlng + rng.gauss(0, s_lng)
        else:
            # Uniform coverage across the whole field.
            lat = clat + rng.uniform(-half_lat, half_lat)
            lng = clng + rng.uniform(-half_lng, half_lng)
        # Keep within the field bounds.
        lat = min(clat + half_lat, max(clat - half_lat, lat))
        lng = min(clng + half_lng, max(clng - half_lng, lng))
        pts.append([round(lat, 6), round(lng, 6)])
    return pts


def seed_football(user):
    points = football_heatmap_points()
    duration_min = 60
    weight = float(getattr(getattr(user, "profile", None), "weight_kg", 75) or 75)
    kcal = calories_for(met_for(FOOTBALL_KEY), weight, duration_min)

    ActivityLogModel.objects.filter(
        user=user, activity_key=FOOTBALL_KEY, performed_at=WHEN
    ).delete()
    log = ActivityLogModel.objects.create(
        user=user, activity_key=FOOTBALL_KEY, duration_min=duration_min,
        distance_km=None, calories=kcal, performed_at=WHEN, route=points,
    )
    print("Actividad creada (mapa de calor):")
    print(f"  id={log.pk}  {FOOTBALL_KEY}  {WHEN}")
    print(f"  puntos      : {len(points)}")
    print(f"  duración    : {duration_min} min")
    print(f"  calorías    : {kcal:.0f} kcal (peso {weight} kg)")


def main():
    User = get_user_model()
    user = User.objects.filter(email=EMAIL).first()
    if not user:
        print(f"ERROR: no existe el usuario {EMAIL}")
        return

    route = densify(WAYPOINTS, steps=8)

    # Total distance (m -> km) along the densified route.
    dist_m = sum(haversine_m(route[i], route[i + 1]) for i in range(len(route) - 1))
    distance_km = round(dist_m / 1000.0, 2)

    # Duration at ~5:40 min/km (a realistic steady running pace).
    duration_min = max(1, round(distance_km * 5.67))

    weight = float(getattr(getattr(user, "profile", None), "weight_kg", 75) or 75)
    kcal = calories_for(met_for(ACTIVITY), weight, duration_min)

    # Idempotency: delete that day's running if it already exists.
    ActivityLogModel.objects.filter(
        user=user, activity_key=ACTIVITY, performed_at=WHEN
    ).delete()

    log = ActivityLogModel.objects.create(
        user=user, activity_key=ACTIVITY, duration_min=duration_min,
        distance_km=distance_km, calories=kcal, performed_at=WHEN, route=route,
    )

    print("Actividad creada:")
    print(f"  id={log.pk}  {ACTIVITY}  {WHEN}")
    print(f"  puntos ruta : {len(route)}")
    print(f"  distancia   : {distance_km} km")
    print(f"  duración    : {duration_min} min")
    pace_sec = duration_min * 60 / distance_km
    print(f"  ritmo       : {int(pace_sec // 60)}:{int(pace_sec % 60):02d} /km")
    print(f"  calorías    : {kcal:.0f} kcal (peso {weight} kg)")

    print()
    seed_football(user)


if __name__ == "__main__":
    main()
