from datetime import date

from rest_framework import serializers

from apps.users.domain.entities import ActivityLevel, FitnessGoal


class RegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(min_length=8, write_only=True)
    name = serializers.CharField(max_length=150)
    goal = serializers.ChoiceField(choices=[g.value for g in FitnessGoal])
    weight_kg = serializers.FloatField(min_value=30, max_value=300)
    height_cm = serializers.IntegerField(min_value=100, max_value=250)
    birth_date = serializers.DateField()
    gender = serializers.ChoiceField(choices=["M", "F"])
    activity_level = serializers.ChoiceField(choices=[a.value for a in ActivityLevel])
    training_days_per_week = serializers.IntegerField(min_value=1, max_value=7)

    def validate_birth_date(self, value: date) -> date:
        age = (date.today() - value).days // 365
        if age < 13:
            raise serializers.ValidationError("Debes tener al menos 13 años.")
        if age > 100:
            raise serializers.ValidationError("Fecha de nacimiento no válida.")
        return value


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)


class UpdateProfileSerializer(serializers.Serializer):
    """All fields optional: only what's sent is updated."""

    name = serializers.CharField(max_length=150, required=False)
    goal = serializers.ChoiceField(choices=[g.value for g in FitnessGoal], required=False)
    weight_kg = serializers.FloatField(min_value=30, max_value=300, required=False)
    height_cm = serializers.IntegerField(min_value=100, max_value=250, required=False)
    birth_date = serializers.DateField(required=False)
    gender = serializers.ChoiceField(choices=["M", "F"], required=False)
    activity_level = serializers.ChoiceField(
        choices=[a.value for a in ActivityLevel], required=False
    )
    training_days_per_week = serializers.IntegerField(min_value=1, max_value=7, required=False)
    is_public = serializers.BooleanField(required=False)

    def validate_birth_date(self, value: date) -> date:
        age = (date.today() - value).days // 365
        if age < 13:
            raise serializers.ValidationError("Debes tener al menos 13 años.")
        if age > 100:
            raise serializers.ValidationError("Fecha de nacimiento no válida.")
        return value


class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(min_length=8, write_only=True)


class MacroTargetsSerializer(serializers.Serializer):
    kcal = serializers.IntegerField()
    protein_g = serializers.IntegerField()
    carbs_g = serializers.IntegerField()
    fat_g = serializers.IntegerField()


class UserProfileSerializer(serializers.Serializer):
    # goal and activity_level are Enums (str, Enum); we use `.value` to emit
    # 'lose_fat' instead of 'FitnessGoal.LOSE_FAT' (which broke the PATCH
    # round-trip, because the ChoiceField rejected the returned value).
    goal = serializers.SerializerMethodField()
    weight_kg = serializers.FloatField()
    height_cm = serializers.IntegerField()
    birth_date = serializers.DateField()
    gender = serializers.CharField()
    activity_level = serializers.SerializerMethodField()
    training_days_per_week = serializers.IntegerField()
    is_public = serializers.BooleanField()
    macro_targets = MacroTargetsSerializer()

    def get_goal(self, obj) -> str:
        return getattr(obj.goal, "value", obj.goal)

    def get_activity_level(self, obj) -> str:
        return getattr(obj.activity_level, "value", obj.activity_level)


class UserSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    email = serializers.EmailField()
    name = serializers.CharField()
    profile = UserProfileSerializer(allow_null=True)
    created_at = serializers.DateTimeField()


class AuthResponseSerializer(serializers.Serializer):
    user = UserSerializer()
    access_token = serializers.CharField()
    refresh_token = serializers.CharField()
