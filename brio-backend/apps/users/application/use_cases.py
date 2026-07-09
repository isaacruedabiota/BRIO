"""
User use cases. They only depend on interfaces (the D of SOLID).
They import nothing from Django, DRF or the ORM — testable in isolation.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Protocol

from core.application.use_case import UseCase
from core.exceptions import DuplicateEntityError, EntityNotFoundError, UnauthorizedError
from apps.users.domain.entities import (
    ActivityLevel,
    FitnessGoal,
    User,
    UserProfile,
)
from apps.users.domain.repositories import IUserRepository


# Token service protocol (the D of SOLID).
class ITokenService(Protocol):
    def generate_tokens(self, user: User) -> dict[str, str]:
        ...

    def verify_token(self, token: str) -> int:
        """Returns the user_id if the token is valid, raises UnauthorizedError otherwise."""
        ...


# DTOs.
@dataclass(frozen=True)
class RegisterUserInput:
    email: str
    password: str
    name: str
    goal: FitnessGoal
    weight_kg: float
    height_cm: int
    birth_date: date
    gender: str
    activity_level: ActivityLevel
    training_days_per_week: int


@dataclass(frozen=True)
class RegisterUserOutput:
    user: User
    access_token: str
    refresh_token: str


@dataclass(frozen=True)
class LoginInput:
    email: str
    password: str


@dataclass(frozen=True)
class LoginOutput:
    user: User
    access_token: str
    refresh_token: str


@dataclass(frozen=True)
class GetUserProfileInput:
    user_id: int


@dataclass(frozen=True)
class UpdateProfileInput:
    user_id: int
    name: str | None = None
    goal: FitnessGoal | None = None
    weight_kg: float | None = None
    height_cm: int | None = None
    birth_date: date | None = None
    gender: str | None = None
    activity_level: ActivityLevel | None = None
    training_days_per_week: int | None = None
    is_public: bool | None = None


@dataclass(frozen=True)
class ChangePasswordInput:
    user_id: int
    current_password: str
    new_password: str


@dataclass(frozen=True)
class DeleteAccountInput:
    user_id: int


# Use cases.
class RegisterUserUseCase(UseCase[RegisterUserInput, RegisterUserOutput]):
    """
    S: only handles registration.
    D: depends on IUserRepository and ITokenService, not concrete implementations.
    """

    def __init__(
        self,
        user_repository: IUserRepository,
        token_service: ITokenService,
        password_hasher,
    ) -> None:
        self._repo = user_repository
        self._tokens = token_service
        self._hasher = password_hasher

    def execute(self, input_dto: RegisterUserInput) -> RegisterUserOutput:
        if self._repo.exists_by_email(input_dto.email):
            raise DuplicateEntityError(f"El email {input_dto.email!r} ya está registrado.")

        profile = UserProfile(
            goal=input_dto.goal,
            weight_kg=input_dto.weight_kg,
            height_cm=input_dto.height_cm,
            birth_date=input_dto.birth_date,
            gender=input_dto.gender,
            activity_level=input_dto.activity_level,
            training_days_per_week=input_dto.training_days_per_week,
        )

        user = User(email=input_dto.email, name=input_dto.name, profile=profile)

        # The concrete repository handles password hashing via Django.
        saved_user = self._repo.save(user, raw_password=input_dto.password)
        tokens = self._tokens.generate_tokens(saved_user)

        return RegisterUserOutput(
            user=saved_user,
            access_token=tokens["access"],
            refresh_token=tokens["refresh"],
        )


class LoginUseCase(UseCase[LoginInput, LoginOutput]):

    def __init__(
        self,
        user_repository: IUserRepository,
        token_service: ITokenService,
        password_checker,
    ) -> None:
        self._repo = user_repository
        self._tokens = token_service
        self._checker = password_checker

    def execute(self, input_dto: LoginInput) -> LoginOutput:
        user = self._repo.find_by_email(input_dto.email)
        if user is None:
            raise UnauthorizedError("Credenciales incorrectas.")

        if not self._checker(user.id, input_dto.password):
            raise UnauthorizedError("Credenciales incorrectas.")

        tokens = self._tokens.generate_tokens(user)

        return LoginOutput(
            user=user,
            access_token=tokens["access"],
            refresh_token=tokens["refresh"],
        )


class GetUserProfileUseCase(UseCase[GetUserProfileInput, User]):

    def __init__(self, user_repository: IUserRepository) -> None:
        self._repo = user_repository

    def execute(self, input_dto: GetUserProfileInput) -> User:
        user = self._repo.find_by_id(input_dto.user_id)
        if user is None:
            raise EntityNotFoundError(f"Usuario {input_dto.user_id} no encontrado.")
        return user


class UpdateProfileUseCase(UseCase[UpdateProfileInput, User]):
    """
    Updates the user's data and profile. Rebuilding the `UserProfile`
    recalculates the macro targets automatically (`__post_init__`).
    Only applies the fields sent (`None` ones keep their current value).
    """

    def __init__(self, user_repository: IUserRepository) -> None:
        self._repo = user_repository

    def execute(self, input_dto: UpdateProfileInput) -> User:
        user = self._repo.find_by_id(input_dto.user_id)
        if user is None:
            raise EntityNotFoundError(f"Usuario {input_dto.user_id} no encontrado.")
        if user.profile is None:
            raise EntityNotFoundError("El usuario no tiene perfil que actualizar.")

        p = user.profile
        updated_profile = UserProfile(
            goal=input_dto.goal if input_dto.goal is not None else p.goal,
            weight_kg=input_dto.weight_kg if input_dto.weight_kg is not None else p.weight_kg,
            height_cm=input_dto.height_cm if input_dto.height_cm is not None else p.height_cm,
            birth_date=input_dto.birth_date if input_dto.birth_date is not None else p.birth_date,
            gender=input_dto.gender if input_dto.gender is not None else p.gender,
            activity_level=input_dto.activity_level
            if input_dto.activity_level is not None
            else p.activity_level,
            training_days_per_week=input_dto.training_days_per_week
            if input_dto.training_days_per_week is not None
            else p.training_days_per_week,
            is_public=input_dto.is_public
            if input_dto.is_public is not None
            else p.is_public,
        )

        updated_user = User(
            id=user.id,
            email=user.email,
            name=input_dto.name if input_dto.name is not None else user.name,
            profile=updated_profile,
            is_active=user.is_active,
            created_at=user.created_at,
        )
        return self._repo.save(updated_user)


class ChangePasswordUseCase(UseCase[ChangePasswordInput, None]):

    def __init__(self, user_repository: IUserRepository, password_checker) -> None:
        self._repo = user_repository
        self._checker = password_checker

    def execute(self, input_dto: ChangePasswordInput) -> None:
        if not self._checker(input_dto.user_id, input_dto.current_password):
            raise UnauthorizedError("La contraseña actual no es correcta.")
        self._repo.set_password(input_dto.user_id, input_dto.new_password)


class DeleteAccountUseCase(UseCase[DeleteAccountInput, None]):

    def __init__(self, user_repository: IUserRepository) -> None:
        self._repo = user_repository

    def execute(self, input_dto: DeleteAccountInput) -> None:
        self._repo.delete(input_dto.user_id)
