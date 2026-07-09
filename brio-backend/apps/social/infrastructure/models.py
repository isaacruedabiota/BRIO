from django.db import models

from apps.training.infrastructure.models import (
    ActivityLogModel,
    WorkoutSessionModel,
)
from apps.users.infrastructure.models import UserModel


class FollowModel(models.Model):
    """One-directional follow relation: `follower` follows `following`."""

    follower = models.ForeignKey(
        UserModel, on_delete=models.CASCADE, related_name="following_set"
    )
    following = models.ForeignKey(
        UserModel, on_delete=models.CASCADE, related_name="follower_set"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "social_follows"
        unique_together = [("follower", "following")]
        indexes = [
            models.Index(fields=["follower"]),
            models.Index(fields=["following"]),
        ]

    def __str__(self) -> str:
        return f"{self.follower.email} → {self.following.email}"


class PostModel(models.Model):
    """Feed post: text + optional image + attached workout/activity."""

    author = models.ForeignKey(
        UserModel, on_delete=models.CASCADE, related_name="posts"
    )
    text = models.TextField(blank=True, default="")
    image = models.ImageField(upload_to="posts/", null=True, blank=True)
    workout_session = models.ForeignKey(
        WorkoutSessionModel, on_delete=models.SET_NULL, null=True, blank=True
    )
    activity_log = models.ForeignKey(
        ActivityLogModel, on_delete=models.SET_NULL, null=True, blank=True
    )
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = "social_posts"
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["author", "created_at"])]

    def __str__(self) -> str:
        return f"Post({self.author.email}, {self.created_at:%Y-%m-%d})"


class PostLikeModel(models.Model):
    post = models.ForeignKey(
        PostModel, on_delete=models.CASCADE, related_name="likes"
    )
    user = models.ForeignKey(
        UserModel, on_delete=models.CASCADE, related_name="post_likes"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "social_post_likes"
        unique_together = [("post", "user")]


class CommentModel(models.Model):
    post = models.ForeignKey(
        PostModel, on_delete=models.CASCADE, related_name="comments"
    )
    author = models.ForeignKey(
        UserModel, on_delete=models.CASCADE, related_name="comments"
    )
    text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "social_comments"
        ordering = ["created_at"]

    def __str__(self) -> str:
        return f"Comment({self.author.email} on {self.post_id})"
