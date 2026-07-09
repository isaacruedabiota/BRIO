"""
Concrete implementation of the user repository using the Django ORM.
Implements IUserRepository (the L of SOLID — Liskov Substitution).
Maps between ORM models and domain entities.
"""
from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Optional

from django.contrib.auth.hashers import check_password

from apps.users.domain.entities import (
    ActivityLevel,
    FitnessGoal,
    MacroTargets,
    User,
    UserProfile,
)
from apps.users.domain.repositories import IUserRepository
from apps.users.infrastructure.models import (
    MacroTargetHistoryModel,
    UserModel,
    UserProfileModel,
)


class DjangoUserRepository(IUserRepository):

    # IUserRepository.

    def find_by_id(self, entity_id: int) -> Optional[User]:
        try:
            model = UserModel.objects.select_related("profile").get(pk=entity_id)
            return self._to_entity(model)
        except UserModel.DoesNotExist:
            return None

    def find_by_email(self, email: str) -> Optional[User]:
        try:
            model = UserModel.objects.select_related("profile").get(email=email)
            return self._to_entity(model)
        except UserModel.DoesNotExist:
            return None

    def exists_by_email(self, email: str) -> bool:
        return UserModel.objects.filter(email=email).exists()

    def save(self, entity: User, raw_password: str | None = None) -> User:
        if entity.id is None:
            return self._create(entity, raw_password)
        return self._update(entity)

    def delete(self, entity_id: int) -> None:
        UserModel.objects.filter(pk=entity_id).delete()

    def check_password(self, user_id: int, raw_password: str) -> bool:
        try:
            model = UserModel.objects.get(pk=user_id)
            return model.check_password(raw_password)
        except UserModel.DoesNotExist:
            return False

    def set_password(self, user_id: int, raw_password: str) -> None:
        model = UserModel.objects.get(pk=user_id)
        model.set_password(raw_password)
        model.save(update_fields=["password"])

    # ORM ↔ domain mapping.

    def _create(self, entity: User, raw_password: str) -> User:
        user_model = UserModel(email=entity.email, name=entity.name)
        user_model.set_password(raw_password)
        user_model.save()

        if entity.profile:
            self._save_profile(user_model, entity.profile)

        return self._to_entity(
            UserModel.objects.select_related("profile").get(pk=user_model.pk)
        )

    def _update(self, entity: User) -> User:
        UserModel.objects.filter(pk=entity.id).update(
            name=entity.name,
            is_active=entity.is_active,
        )
        if entity.profile:
            model = UserModel.objects.get(pk=entity.id)
            self._save_profile(model, entity.profile)

        return self._to_entity(
            UserModel.objects.select_related("profile").get(pk=entity.id)
        )

    def _save_profile(self, user_model: UserModel, profile: UserProfile) -> None:
        t = profile.macro_targets
        UserProfileModel.objects.update_or_create(
            user=user_model,
            defaults={
                "goal": profile.goal.value,
                "weight_kg": profile.weight_kg,
                "height_cm": profile.height_cm,
                "birth_date": profile.birth_date,
                "gender": profile.gender,
                "activity_level": profile.activity_level.value,
                "training_days_per_week": profile.training_days_per_week,
                "is_public": profile.is_public,
                "daily_kcal_target": t.kcal,
                "protein_g_target": t.protein_g,
                "carbs_g_target": t.carbs_g,
                "fat_g_target": t.fat_g,
            },
        )
        # Snapshot of the target in effect TODAY (past days are untouched).
        MacroTargetHistoryModel.objects.update_or_create(
            user=user_model,
            effective_date=date.today(),
            defaults={
                "daily_kcal_target": t.kcal,
                "protein_g_target": t.protein_g,
                "carbs_g_target": t.carbs_g,
                "fat_g_target": t.fat_g,
            },
        )

    @staticmethod
    def _to_entity(model: UserModel) -> User:
        profile: Optional[UserProfile] = None

        if hasattr(model, "profile"):
            p = model.profile
            domain_profile = UserProfile(
                goal=FitnessGoal(p.goal),
                weight_kg=p.weight_kg,
                height_cm=p.height_cm,
                birth_date=p.birth_date,
                gender=p.gender,
                activity_level=ActivityLevel(p.activity_level),
                training_days_per_week=p.training_days_per_week,
                is_public=p.is_public,
            )
            profile = domain_profile

        return User(
            id=model.pk,
            email=model.email,
            name=model.name,
            profile=profile,
            is_active=model.is_active,
            created_at=model.date_joined,
        )
