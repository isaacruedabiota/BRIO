"""
Base interface for all repositories (the D of SOLID — Dependency Inversion).
The Application layers depend on this abstraction, never on the ORM.
"""
from abc import ABC, abstractmethod
from typing import Generic, Optional, TypeVar

T = TypeVar("T")   # Domain entity
ID = TypeVar("ID")  # Identifier type


class Repository(ABC, Generic[T, ID]):
    """
    Base contract. Every concrete repository must implement these operations.
    Use cases receive IUserRepository, INutritionRepository, etc. — never Django
    ORM instances directly.
    """

    @abstractmethod
    def find_by_id(self, entity_id: ID) -> Optional[T]:
        ...

    @abstractmethod
    def save(self, entity: T) -> T:
        ...

    @abstractmethod
    def delete(self, entity_id: ID) -> None:
        ...
