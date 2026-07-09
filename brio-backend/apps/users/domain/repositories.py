"""
User repository interface (the I of SOLID — Interface Segregation).
Only declares what this module's use cases need.
"""
from abc import abstractmethod
from typing import Optional

from core.domain.repository import Repository
from apps.users.domain.entities import User


class IUserRepository(Repository[User, int]):

    @abstractmethod
    def find_by_email(self, email: str) -> Optional[User]:
        ...

    @abstractmethod
    def exists_by_email(self, email: str) -> bool:
        ...

    @abstractmethod
    def set_password(self, user_id: int, raw_password: str) -> None:
        ...
