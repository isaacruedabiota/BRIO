from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

urlpatterns = [
    path("admin/", admin.site.urls),
    # Auth.
    path("api/auth/", include("apps.users.presentation.urls")),
    # Nutrition.
    path("api/nutrition/", include("apps.nutrition.presentation.urls")),
    # Training.
    path("api/training/",  include("apps.training.presentation.urls")),
    # Social.
    path("api/social/",    include("apps.social.presentation.urls")),
    # OpenAPI docs (development only).
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
]

# Serve media in development (in production Nginx / object storage serves it).
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
