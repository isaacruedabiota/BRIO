"""
Production settings (expose the backend to the internet behind Caddy + HTTPS).

Enabled with:  DJANGO_SETTINGS_MODULE=config.settings.production
Reads sensitive values from `.env` (see .env.example).
"""
from decouple import Csv, config

from .base import *  # noqa: F401, F403
from .base import BASE_DIR, MIDDLEWARE

DEBUG = False

# Required in production (no default → fails if missing, on purpose).
SECRET_KEY = config("SECRET_KEY")

# Domain(s) it's served on. E.g. "yourdomain.duckdns.org,127.0.0.1,localhost".
ALLOWED_HOSTS = config("ALLOWED_HOSTS", default="localhost,127.0.0.1", cast=Csv())

# Caddy terminates TLS and forwards to waitress; we trust its protocol header.
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
USE_X_FORWARDED_HOST = True

# To reach /admin over HTTPS. E.g. "https://yourdomain.duckdns.org".
CSRF_TRUSTED_ORIGINS = config("CSRF_TRUSTED_ORIGINS", default="", cast=Csv())

# Security cookies and headers.
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
# Caddy already redirects to HTTPS; we don't do it in Django to avoid redirect loops.
SECURE_SSL_REDIRECT = False

# The mobile app (Dio) doesn't use CORS; we close it in production.
CORS_ALLOW_ALL_ORIGINS = False

# Static files served by WhiteNoise (/admin needs its CSS/JS).
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_STORAGE = "whitenoise.storage.CompressedStaticFilesStorage"
# WhiteNoise right after the SecurityMiddleware.
if "whitenoise.middleware.WhiteNoiseMiddleware" not in MIDDLEWARE:
    MIDDLEWARE.insert(1, "whitenoise.middleware.WhiteNoiseMiddleware")
