"""
Generates demonstration videos (looping MP4) for exercises, from the 2 photos
(start/end) in free-exercise-db (public domain).

    python manage.py import_exercise_media

Requires ffmpeg. Downloads the images, builds a short MP4 alternating the two
poses (animation effect) and fills Exercise.gif_url.
"""
import shutil
import subprocess
import tempfile
import urllib.request
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand

from apps.training.infrastructure.models import ExerciseModel

_INDEX_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"
_IMG_BASE  = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

# Mapping: our exercise (ES) → keywords to search in free-exercise-db (EN).
# The first exercise whose name contains ALL the keywords is chosen.
_MAP = {
    "Press de banca":               ["barbell", "bench", "press"],
    "Press de banca inclinado":     ["incline", "bench", "press"],
    "Press de banca con mancuernas":["dumbbell", "bench", "press"],
    "Aperturas con mancuernas":     ["dumbbell", "flyes"],
    "Fondos en paralelas":          ["dips", "chest"],
    "Cruces en polea":              ["cable", "crossover"],
    "Peso muerto":                  ["barbell", "deadlift"],
    "Dominadas":                    ["pullups"],
    "Remo con barra":               ["bent over barbell row"],
    "Remo con mancuerna":           ["one-arm dumbbell row"],
    "Jalón al pecho":               ["wide-grip lat pulldown"],
    "Remo en polea baja":           ["seated cable rows"],
    "Press militar con barra":      ["standing military press"],
    "Press de hombros mancuernas":  ["dumbbell shoulder press"],
    "Elevaciones laterales":        ["side lateral raise"],
    "Elevaciones frontales":        ["front dumbbell raise"],
    "Face pulls":                   ["face pull"],
    "Sentadilla con barra":         ["barbell full squat"],
    "Sentadilla frontal":           ["front barbell squat"],
    "Prensa de pierna":             ["leg press"],
    "Extensión de cuádriceps":      ["leg extensions"],
    "Curl femoral tumbado":         ["lying leg curls"],
    "Peso muerto rumano":           ["romanian deadlift"],
    "Hip thrust":                   ["barbell hip thrust"],
    "Zancadas":                     ["dumbbell lunges"],
    "Elevación de gemelos de pie":  ["standing calf raises"],
    "Curl de bíceps con barra":     ["barbell curl"],
    "Curl con mancuernas alterno":  ["alternate", "dumbbell curl"],
    "Curl martillo":                ["hammer curl"],
    "Curl en polea baja":           ["cable curl"],
    "Press francés":                ["lying triceps press"],
    "Extensión de tríceps polea":   ["triceps pushdown"],
    "Patada de tríceps":            ["tricep dumbbell kickback"],
    "Plancha":                      ["plank"],
    "Crunch abdominal":             ["crunch"],
    "Rueda abdominal":              ["roller"],
}


class Command(BaseCommand):
    help = "Genera vídeos de demostración de ejercicios desde free-exercise-db"

    def handle(self, *args, **options):
        ffmpeg = self._find_ffmpeg()
        if not ffmpeg:
            self.stderr.write("ffmpeg no encontrado.")
            return

        self.stdout.write("Descargando índice de free-exercise-db...")
        import json
        with urllib.request.urlopen(_INDEX_URL, timeout=30) as r:
            index = json.loads(r.read())

        out_dir = Path(settings.MEDIA_ROOT) / "exercises"
        out_dir.mkdir(parents=True, exist_ok=True)

        ok, fail = 0, 0
        for name_es, keywords in _MAP.items():
            ex = ExerciseModel.objects.filter(name=name_es).first()
            if ex is None:
                continue

            match = self._find_match(index, keywords)
            if match is None or len(match.get("images", [])) < 2:
                self.stdout.write(f"  · sin match: {name_es}")
                fail += 1
                continue

            slug = ex.pk
            try:
                with tempfile.TemporaryDirectory() as tmp:
                    img0 = Path(tmp) / "0.jpg"
                    img1 = Path(tmp) / "1.jpg"
                    self._download(_IMG_BASE + match["images"][0], img0)
                    self._download(_IMG_BASE + match["images"][1], img1)
                    out = out_dir / f"{slug}.mp4"
                    self._make_video(ffmpeg, img0, img1, out)
                ex.gif_url = f"/media/exercises/{slug}.mp4"
                ex.save(update_fields=["gif_url"])
                ok += 1
                self.stdout.write(self.style.SUCCESS(f"  OK {name_es} -> {match['name']}"))
            except Exception as e:
                fail += 1
                self.stdout.write(f"  · error {name_es}: {str(e)[:60]}")

        self.stdout.write(self.style.SUCCESS(f"\nGenerados {ok} vídeos | {fail} fallos"))

    def _find_match(self, index, keywords):
        kws = [k.lower() for k in keywords]
        candidates = [ex for ex in index if all(k in ex["name"].lower() for k in kws)
                      and len(ex.get("images", [])) >= 2]
        if not candidates:
            return None
        # The shortest name is usually the most generic/correct exercise
        # (e.g. "Leg Press" over "Calf Press On The Leg Press Machine").
        return min(candidates, key=lambda e: len(e["name"]))

    def _download(self, url, dest: Path):
        req = urllib.request.Request(url, headers={"User-Agent": "BRIO/0.1"})
        with urllib.request.urlopen(req, timeout=30) as r, open(dest, "wb") as f:
            shutil.copyfileobj(r, f)

    def _make_video(self, ffmpeg, img0: Path, img1: Path, out: Path):
        # ~1.2s MP4 alternating the two poses; the client plays it in a loop.
        cmd = [
            ffmpeg, "-y",
            "-loop", "1", "-t", "0.6", "-i", str(img0),
            "-loop", "1", "-t", "0.6", "-i", str(img1),
            "-filter_complex",
            "[0:v]scale=420:-2,setsar=1[a];[1:v]scale=420:-2,setsar=1[b];"
            "[a][b]concat=n=2:v=1:a=0,fps=15,format=yuv420p[v]",
            "-map", "[v]", "-movflags", "+faststart", str(out),
        ]
        subprocess.run(cmd, check=True, capture_output=True)

    def _find_ffmpeg(self):
        f = shutil.which("ffmpeg")
        if f:
            return f
        # Typical winget path (Gyan.FFmpeg).
        import glob, os
        pattern = os.path.join(
            os.environ.get("LOCALAPPDATA", ""),
            "Microsoft", "WinGet", "Packages", "Gyan.FFmpeg*", "**", "ffmpeg.exe",
        )
        hits = glob.glob(pattern, recursive=True)
        return hits[0] if hits else None
