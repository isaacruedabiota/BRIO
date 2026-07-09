from django.apps import AppConfig


class UsersInfrastructureConfig(AppConfig):
    name = "apps.users.infrastructure"
    label = "infrastructure"
    verbose_name = "Users"

    def ready(self) -> None:
        pass
