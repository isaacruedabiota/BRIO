"""
Base contract for all use cases (the S of SOLID — Single Responsibility).
Each UseCase does exactly one thing through execute().
"""
from abc import ABC, abstractmethod
from typing import Generic, TypeVar

InputDTO = TypeVar("InputDTO")
OutputDTO = TypeVar("OutputDTO")


class UseCase(ABC, Generic[InputDTO, OutputDTO]):
    @abstractmethod
    def execute(self, input_dto: InputDTO) -> OutputDTO:
        ...
