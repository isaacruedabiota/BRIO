from django.urls import path

from apps.social.presentation.views import (
    CommentListCreateView,
    FeedView,
    FollowView,
    LikeView,
    PostDetailView,
    PostListCreateView,
    UserProfileDetailView,
    UserSearchView,
)

urlpatterns = [
    path("feed/", FeedView.as_view(), name="social-feed"),
    path("posts/", PostListCreateView.as_view(), name="social-posts"),
    path("posts/<int:post_id>/", PostDetailView.as_view(), name="social-post-detail"),
    path("posts/<int:post_id>/like/", LikeView.as_view(), name="social-post-like"),
    path("posts/<int:post_id>/comments/", CommentListCreateView.as_view(), name="social-post-comments"),
    path("users/search/", UserSearchView.as_view(), name="social-user-search"),
    path("users/<int:user_id>/follow/", FollowView.as_view(), name="social-follow"),
    path("users/<int:user_id>/", UserProfileDetailView.as_view(), name="social-user-detail"),
]
