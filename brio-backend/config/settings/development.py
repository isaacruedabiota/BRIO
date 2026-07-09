from .base import *  # noqa: F401, F403

DEBUG = True
# 10.0.2.2 = the PC host as seen from the Android emulator.
ALLOWED_HOSTS = ["localhost", "127.0.0.1", "10.0.2.2"]

CORS_ALLOW_ALL_ORIGINS = True  # development only
