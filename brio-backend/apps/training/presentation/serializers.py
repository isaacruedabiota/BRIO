from rest_framework import serializers

from apps.training.domain.entities import Equipment, MuscleGroup


class ExerciseSerializer(serializers.Serializer):
    id            = serializers.IntegerField()
    name          = serializers.CharField()
    muscle_groups = serializers.ListField(child=serializers.CharField())
    equipment     = serializers.CharField()
    instructions  = serializers.CharField(allow_null=True)
    is_custom     = serializers.BooleanField()

    def to_representation(self, ex):
        return {
            "id":            ex.id,
            "name":          ex.name,
            "muscle_groups": [g.value for g in ex.muscle_groups],
            "equipment":     ex.equipment.value,
            "instructions":  ex.instructions,
            "gif_url":       ex.gif_url,
            "is_custom":     ex.is_custom,
        }


class RoutineExerciseSerializer(serializers.Serializer):
    def to_representation(self, re):
        return {
            "id":           re.id,
            "exercise":     ExerciseSerializer().to_representation(re.exercise),
            "sets":         re.sets,
            "reps":         re.reps,
            "rest_seconds": re.rest_seconds,
            "order":        re.order,
        }


class RoutineSerializer(serializers.Serializer):
    def to_representation(self, routine):
        return {
            "id":        routine.id,
            "name":      routine.name,
            "exercises": [RoutineExerciseSerializer().to_representation(e) for e in routine.exercises],
        }


class WorkoutSetSerializer(serializers.Serializer):
    def to_representation(self, s):
        return {
            "id":            s.id,
            "exercise":      ExerciseSerializer().to_representation(s.exercise),
            "reps":          s.reps,
            "weight_kg":     s.weight_kg,
            "set_number":    s.set_number,
            "rpe":           s.rpe,
            "set_type":      s.set_type.value,
            "is_warmup":     s.is_warmup,
            "is_pr":         s.is_pr,
            "estimated_1rm": s.estimated_1rm,
            "volume":        s.volume,
        }


class WorkoutSessionSerializer(serializers.Serializer):
    def to_representation(self, session):
        return {
            "id":             session.id,
            "routine":        {"id": session.routine.id, "name": session.routine.name} if session.routine else None,
            "sets":           [WorkoutSetSerializer().to_representation(s) for s in session.sets],
            "started_at":     session.started_at.isoformat() if session.started_at else None,
            "finished_at":    session.finished_at.isoformat() if session.finished_at else None,
            "is_active":      session.is_active,
            "duration_min":   session.duration_minutes,
            "total_volume_kg":session.total_volume_kg,
            "pr_count":       session.pr_count,
            "notes":          session.notes,
        }


# ── Input serializers ─────────────────────────────────────────────────────────

class RoutineExerciseInputSerializer(serializers.Serializer):
    exercise_id  = serializers.IntegerField()
    sets         = serializers.IntegerField(min_value=1, max_value=20)
    reps         = serializers.IntegerField(min_value=1, max_value=100)
    rest_seconds = serializers.IntegerField(min_value=10, max_value=600, default=90)
    order        = serializers.IntegerField(min_value=0, default=0)


class CreateRoutineSerializer(serializers.Serializer):
    name      = serializers.CharField(max_length=200)
    exercises = RoutineExerciseInputSerializer(many=True, default=list)


class StartSessionSerializer(serializers.Serializer):
    routine_id = serializers.IntegerField(required=False, allow_null=True)


class LogSetSerializer(serializers.Serializer):
    exercise_id = serializers.IntegerField()
    reps        = serializers.IntegerField(min_value=1, max_value=200)
    weight_kg   = serializers.FloatField(min_value=0)
    set_number  = serializers.IntegerField(min_value=1)
    rpe         = serializers.IntegerField(min_value=1, max_value=10, required=False, allow_null=True)
    set_type    = serializers.ChoiceField(
        choices=["normal", "warmup", "dropset", "failure"], default="normal")


class FinishSessionSerializer(serializers.Serializer):
    notes = serializers.CharField(required=False, allow_blank=True, allow_null=True)
