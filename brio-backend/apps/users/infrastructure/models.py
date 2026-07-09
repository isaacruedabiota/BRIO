"""
Django ORM models. They live only in the infrastructure layer.
Use cases never import them directly.
"""
from django.contrib.auth.models import AbstractUser
from django.db import models

from apps.users.domain.entities import ActivityLevel, FitnessGoal


class UserModel(AbstractUser):
    """
    Extends AbstractUser to reuse Django's auth system (password hashing,
    permissions, sessions) without reinventing the wheel.
    """

    # AbstractUser already has: username, email, first_name, last_name, password, is_active
    username = None  # we use email as the unique identifier
    email = models.EmailField(unique=True)
    name = models.CharField(max_length=150)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["name"]

    class Meta:
        db_table = "users"
        verbose_name = "Usuario"
        verbose_name_plural = "Usuarios"

    def __str__(self) -> str:
        return self.email


class UserProfileModel(models.Model):

    GENDER_CHOICES = [("M", "Hombre"), ("F", "Mujer")]

    user = models.OneToOneField(
        UserModel,
        on_delete=models.CASCADE,
        related_name="profile",
        db_column="user_id",
    )
    goal = models.CharField(
        max_length=30,
        choices=[(g.value, g.name) for g in FitnessGoal],
    )
    weight_kg = models.FloatField()
    height_cm = models.PositiveSmallIntegerField()
    birth_date = models.DateField()
    gender = models.CharField(max_length=1, choices=GENDER_CHOICES)
    activity_level = models.CharField(
        max_length=20,
        choices=[(a.value, a.name) for a in ActivityLevel],
    )
    training_days_per_week = models.PositiveSmallIntegerField()

    # Privacy: if False, other users don't see the user's progress or posts.
    is_public = models.BooleanField(default=True)

    # Calculated, cached targets (recomputed when the profile is updated).
    daily_kcal_target = models.PositiveSmallIntegerField()
    protein_g_target = models.PositiveSmallIntegerField()
    carbs_g_target = models.PositiveSmallIntegerField()
    fat_g_target = models.PositiveSmallIntegerField()

    class Meta:
        db_table = "user_profiles"

    def __str__(self) -> str:
        return f"Profile({self.user.email})"


class MacroTargetHistoryModel(models.Model):
    """
    History of macro targets with an effective date.

    Every time the user changes their profile, today's row is saved/updated. This
    way each diary day is compared against the target that was active on THAT day
    (past days are not recalculated when the target changes).
    """

    user = models.ForeignKey(
        UserModel,
        on_delete=models.CASCADE,
        related_name="target_history",
        db_column="user_id",
    )
    effective_date = models.DateField()
    daily_kcal_target = models.PositiveSmallIntegerField()
    protein_g_target = models.PositiveSmallIntegerField()
    carbs_g_target = models.PositiveSmallIntegerField()
    fat_g_target = models.PositiveSmallIntegerField()

    class Meta:
        db_table = "macro_target_history"
        unique_together = [("user", "effective_date")]
        indexes = [models.Index(fields=["user", "effective_date"])]
        ordering = ["-effective_date"]

    def __str__(self) -> str:
        return f"{self.user.email} @ {self.effective_date}: {self.daily_kcal_target} kcal"

    @classmethod
    def applicable_for(cls, user_id: int, on_date):
        """Target in effect on `on_date`: most recent row with effective_date ≤ on_date.
        If the date precedes all history, returns the oldest row."""
        row = (
            cls.objects.filter(user_id=user_id, effective_date__lte=on_date)
            .order_by("-effective_date")
            .first()
        )
        if row is None:
            row = cls.objects.filter(user_id=user_id).order_by("effective_date").first()
        return row
