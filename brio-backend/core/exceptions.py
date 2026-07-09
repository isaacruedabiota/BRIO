"""
Domain exceptions. They don't depend on Django or any framework.
Upper layers (presentation) catch them and translate them to HTTP responses.
"""


class DomainException(Exception):
    """Root of all domain exceptions."""
    pass


class EntityNotFoundError(DomainException):
    pass


class DuplicateEntityError(DomainException):
    pass


class ValidationError(DomainException):
    pass


class UnauthorizedError(DomainException):
    pass


class BusinessRuleViolationError(DomainException):
    pass
