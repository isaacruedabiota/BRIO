"""
DRF views. Single responsibility: translate HTTP ↔ application DTOs.
All business logic lives in the use cases.
Dependencies are injected in __init__ to make testing easier.
"""
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.users.application.use_cases import (
    ChangePasswordInput,
    ChangePasswordUseCase,
    DeleteAccountInput,
    DeleteAccountUseCase,
    GetUserProfileInput,
    GetUserProfileUseCase,
    LoginInput,
    LoginUseCase,
    RegisterUserInput,
    RegisterUserUseCase,
    UpdateProfileInput,
    UpdateProfileUseCase,
)
from apps.users.domain.entities import ActivityLevel, FitnessGoal
from apps.users.infrastructure.repositories import DjangoUserRepository
from apps.users.infrastructure.token_service import SimpleJWTTokenService
from apps.users.presentation.serializers import (
    AuthResponseSerializer,
    ChangePasswordSerializer,
    LoginSerializer,
    RegisterSerializer,
    UpdateProfileSerializer,
    UserSerializer,
)
from core.exceptions import (
    DuplicateEntityError,
    EntityNotFoundError,
    UnauthorizedError,
)


def _build_dependencies():
    repo = DjangoUserRepository()
    tokens = SimpleJWTTokenService()
    return repo, tokens


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request: Request) -> Response:
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        repo, tokens = _build_dependencies()
        use_case = RegisterUserUseCase(
            user_repository=repo,
            token_service=tokens,
            password_hasher=None,   # the repo handles hashing internally
        )

        try:
            output = use_case.execute(
                RegisterUserInput(
                    email=data["email"],
                    password=data["password"],
                    name=data["name"],
                    goal=FitnessGoal(data["goal"]),
                    weight_kg=data["weight_kg"],
                    height_cm=data["height_cm"],
                    birth_date=data["birth_date"],
                    gender=data["gender"],
                    activity_level=ActivityLevel(data["activity_level"]),
                    training_days_per_week=data["training_days_per_week"],
                )
            )
        except DuplicateEntityError as e:
            return Response({"detail": str(e)}, status=status.HTTP_409_CONFLICT)

        return Response(
            _serialize_auth(output),
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request: Request) -> Response:
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        repo, tokens = _build_dependencies()
        use_case = LoginUseCase(
            user_repository=repo,
            token_service=tokens,
            password_checker=repo.check_password,
        )

        try:
            output = use_case.execute(LoginInput(
                email=data["email"],
                password=data["password"],
            ))
        except UnauthorizedError:
            return Response(
                {"detail": "Credenciales incorrectas."},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        return Response(_serialize_auth(output), status=status.HTTP_200_OK)


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        repo, _ = _build_dependencies()
        use_case = GetUserProfileUseCase(user_repository=repo)

        try:
            user = use_case.execute(GetUserProfileInput(user_id=request.user.pk))
        except EntityNotFoundError as e:
            return Response({"detail": str(e)}, status=status.HTTP_404_NOT_FOUND)

        return Response(UserSerializer(user).data)

    def patch(self, request: Request) -> Response:
        serializer = UpdateProfileSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        repo, _ = _build_dependencies()
        use_case = UpdateProfileUseCase(user_repository=repo)

        try:
            user = use_case.execute(
                UpdateProfileInput(
                    user_id=request.user.pk,
                    name=data.get("name"),
                    goal=FitnessGoal(data["goal"]) if "goal" in data else None,
                    weight_kg=data.get("weight_kg"),
                    height_cm=data.get("height_cm"),
                    birth_date=data.get("birth_date"),
                    gender=data.get("gender"),
                    activity_level=ActivityLevel(data["activity_level"])
                    if "activity_level" in data
                    else None,
                    training_days_per_week=data.get("training_days_per_week"),
                    is_public=data.get("is_public"),
                )
            )
        except EntityNotFoundError as e:
            return Response({"detail": str(e)}, status=status.HTTP_404_NOT_FOUND)

        return Response(UserSerializer(user).data)

    def delete(self, request: Request) -> Response:
        repo, _ = _build_dependencies()
        use_case = DeleteAccountUseCase(user_repository=repo)
        use_case.execute(DeleteAccountInput(user_id=request.user.pk))
        return Response(status=status.HTTP_204_NO_CONTENT)


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request: Request) -> Response:
        serializer = ChangePasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        repo, _ = _build_dependencies()
        use_case = ChangePasswordUseCase(
            user_repository=repo,
            password_checker=repo.check_password,
        )

        try:
            use_case.execute(
                ChangePasswordInput(
                    user_id=request.user.pk,
                    current_password=data["current_password"],
                    new_password=data["new_password"],
                )
            )
        except UnauthorizedError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(status=status.HTTP_204_NO_CONTENT)


# Helpers.

def _serialize_auth(output) -> dict:
    return {
        "user": UserSerializer(output.user).data,
        "access_token": output.access_token,
        "refresh_token": output.refresh_token,
    }
