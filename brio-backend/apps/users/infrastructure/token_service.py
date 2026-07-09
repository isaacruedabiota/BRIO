"""
JWT token-service adapter (Simple JWT).
Implements the ITokenService protocol defined in application.
"""
from rest_framework_simplejwt.tokens import RefreshToken

from apps.users.domain.entities import User
from core.exceptions import UnauthorizedError


class SimpleJWTTokenService:

    def generate_tokens(self, user: User) -> dict[str, str]:
        from apps.users.infrastructure.models import UserModel
        model = UserModel.objects.get(pk=user.id)
        refresh = RefreshToken.for_user(model)
        return {
            "access": str(refresh.access_token),
            "refresh": str(refresh),
        }

    def verify_token(self, token: str) -> int:
        from rest_framework_simplejwt.tokens import AccessToken
        from rest_framework_simplejwt.exceptions import TokenError
        try:
            decoded = AccessToken(token)
            return decoded["user_id"]
        except TokenError as e:
            raise UnauthorizedError(str(e)) from e
