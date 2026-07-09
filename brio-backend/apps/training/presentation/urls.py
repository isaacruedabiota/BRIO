from django.urls import path

from apps.training.presentation.activity_views import (
    ActivityCatalogView,
    ActivityDetailView,
    ActivityListView,
    BurnedCaloriesView,
)
from apps.training.presentation.highlights_views import HighlightsView
from apps.training.presentation.plan_views import (
    PlanGenerateView,
    PlanScheduleView,
    PlanView,
)
from apps.training.presentation.views import (
    CurrentSessionView,
    DeleteSetView,
    ExerciseDetailView,
    ExerciseLastSetsView,
    ExerciseLibraryView,
    ExerciseProgressView,
    FinishSessionView,
    LogSetView,
    RoutineDetailView,
    RoutineListView,
    WorkoutSessionDetailView,
    WorkoutSessionListView,
)

urlpatterns = [
    # Exercises.
    path("exercises/",                          ExerciseLibraryView.as_view(),      name="exercise-library"),
    path("exercises/<int:exercise_id>/",          ExerciseDetailView.as_view(),   name="exercise-detail"),
    path("exercises/<int:exercise_id>/progress/", ExerciseProgressView.as_view(), name="exercise-progress"),
    path("exercises/<int:exercise_id>/last-sets/", ExerciseLastSetsView.as_view(), name="exercise-last-sets"),
    # Automatic plan (rule-based generator).
    path("plan/generate/",                      PlanGenerateView.as_view(),         name="plan-generate"),
    path("plan/schedule/",                      PlanScheduleView.as_view(),         name="plan-schedule"),
    path("plan/",                               PlanView.as_view(),                 name="plan"),
    # Dashboard highlights.
    path("highlights/",                         HighlightsView.as_view(),           name="highlights"),
    # Routines.
    path("routines/",                           RoutineListView.as_view(),          name="routine-list"),
    path("routines/<int:routine_id>/",          RoutineDetailView.as_view(),        name="routine-detail"),
    # Sessions.
    path("sessions/",                           WorkoutSessionListView.as_view(),   name="session-list"),
    path("sessions/active/",                    CurrentSessionView.as_view(),       name="session-active"),
    path("sessions/<int:session_id>/",          WorkoutSessionDetailView.as_view(), name="session-detail"),
    path("sessions/<int:session_id>/sets/",     LogSetView.as_view(),               name="session-log-set"),
    path("sessions/<int:session_id>/sets/<int:set_id>/", DeleteSetView.as_view(),    name="session-delete-set"),
    path("sessions/<int:session_id>/finish/",   FinishSessionView.as_view(),        name="session-finish"),
    # Cardio/sport activities.
    path("activities/catalog/",                 ActivityCatalogView.as_view(),      name="activity-catalog"),
    path("activities/",                         ActivityListView.as_view(),         name="activity-list"),
    path("activities/<int:activity_id>/",       ActivityDetailView.as_view(),       name="activity-detail"),
    path("burned/",                             BurnedCaloriesView.as_view(),       name="burned-calories"),
]
