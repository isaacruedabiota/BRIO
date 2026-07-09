"""
Social feature views. Direct ORM (like training/saved-meals): the logic is
simple CRUD over the feed, follows, likes and comments.
"""
from django.db.models import F, Q, Sum
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.social.infrastructure.models import (
    CommentModel,
    FollowModel,
    PostLikeModel,
    PostModel,
)
from apps.training.domain.activities import type_for
from apps.training.infrastructure.models import (
    ActivityLogModel,
    WorkoutSessionModel,
    WorkoutSetModel,
)
from apps.users.infrastructure.models import UserModel


def _is_public(user: UserModel) -> bool:
    profile = getattr(user, "profile", None)
    return getattr(profile, "is_public", True)


def _user_stats(user_id: int) -> dict:
    workouts = WorkoutSessionModel.objects.filter(
        user_id=user_id, finished_at__isnull=False
    ).count()
    volume = WorkoutSetModel.objects.filter(
        session__user_id=user_id, session__finished_at__isnull=False, is_warmup=False
    ).aggregate(v=Sum(F("reps") * F("weight_kg")))["v"] or 0
    prs = WorkoutSetModel.objects.filter(
        session__user_id=user_id, is_pr=True
    ).count()
    activities = ActivityLogModel.objects.filter(user_id=user_id).count()
    return {
        "workouts": workouts,
        "volume_kg": round(float(volume), 1),
        "prs": prs,
        "activities": activities,
    }


# Serialization (helpers).

def _author(u: UserModel) -> dict:
    name = (u.name or u.email).strip()
    return {
        "id": u.id,
        "name": name,
        "handle": u.email.split("@")[0],
        "initial": (name[:1] or "?").upper(),
    }


def _workout_summary(s) -> dict | None:
    if s is None:
        return None
    sets = list(s.sets.all())
    volume = sum(x.reps * x.weight_kg for x in sets if not x.is_warmup)
    prs = sum(1 for x in sets if x.is_pr)
    duration = 0
    if s.finished_at and s.started_at:
        duration = int((s.finished_at - s.started_at).total_seconds() // 60)
    return {
        "id": s.id,
        "name": s.routine.name if s.routine else "Entreno",
        "duration_min": duration,
        "volume_kg": round(volume, 1),
        "pr_count": prs,
        "set_count": len(sets),
    }


def _activity_summary(a) -> dict | None:
    if a is None:
        return None
    t = type_for(a.activity_key)
    return {
        "id": a.id,
        "key": a.activity_key,
        "name": t.name_es if t else a.activity_key,
        "icon": t.icon if t else "more_horiz",
        "category": t.category if t else "other",
        "duration_min": a.duration_min,
        "distance_km": a.distance_km,
        "calories": a.calories,
        "has_route": bool(a.route),
    }


def _post(p, request, me_id: int) -> dict:
    image = request.build_absolute_uri(p.image.url) if p.image else None
    return {
        "id": p.id,
        "author": _author(p.author),
        "text": p.text,
        "image": image,
        "workout": _workout_summary(p.workout_session),
        "activity": _activity_summary(p.activity_log),
        "created_at": p.created_at.isoformat(),
        "like_count": p.likes.count(),
        "comment_count": p.comments.count(),
        "liked_by_me": p.likes.filter(user_id=me_id).exists(),
        "is_mine": p.author_id == me_id,
    }


def _comment(c) -> dict:
    return {
        "id": c.id,
        "author": _author(c.author),
        "text": c.text,
        "created_at": c.created_at.isoformat(),
    }


_POST_QS = lambda: PostModel.objects.select_related(  # noqa: E731
    "author", "workout_session", "workout_session__routine", "activity_log"
).prefetch_related("workout_session__sets", "likes", "comments")


# Feed and posts.

class FeedView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        me = request.user.pk
        limit = min(int(request.query_params.get("limit", 30)), 50)
        offset = int(request.query_params.get("offset", 0))

        following = FollowModel.objects.filter(follower_id=me).values_list(
            "following_id", flat=True
        )
        author_ids = list(following) + [me]
        # Privacy: only posts from public accounts (or your own).
        posts = (
            _POST_QS()
            .filter(author_id__in=author_ids)
            .filter(Q(author__profile__is_public=True) | Q(author_id=me))
        )[offset:offset + limit]
        return Response([_post(p, request, me) for p in posts])


class PostListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request: Request) -> Response:
        me = request.user
        text = (request.data.get("text") or "").strip()
        image = request.FILES.get("image")
        ws_id = request.data.get("workout_session_id")
        al_id = request.data.get("activity_log_id")

        if not text and not image and not ws_id and not al_id:
            return Response(
                {"detail": "La publicación no puede estar vacía."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        post = PostModel(author=me, text=text)
        if image:
            post.image = image
        if ws_id:
            session = WorkoutSessionModel.objects.filter(id=ws_id, user=me).first()
            if session is None:
                return Response({"detail": "Entreno no válido."}, status=400)
            post.workout_session = session
        if al_id:
            activity = ActivityLogModel.objects.filter(id=al_id, user=me).first()
            if activity is None:
                return Response({"detail": "Actividad no válida."}, status=400)
            post.activity_log = activity

        post.save()
        post = _POST_QS().get(pk=post.pk)
        return Response(_post(post, request, me.pk), status=status.HTTP_201_CREATED)


class PostDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request: Request, post_id: int) -> Response:
        post = _POST_QS().filter(pk=post_id).first()
        if post is None:
            return Response({"detail": "No encontrado."}, status=404)
        return Response(_post(post, request, request.user.pk))

    def delete(self, request: Request, post_id: int) -> Response:
        post = PostModel.objects.filter(pk=post_id).first()
        if post is None:
            return Response({"detail": "No encontrado."}, status=404)
        if post.author_id != request.user.pk:
            return Response({"detail": "No es tu publicación."}, status=403)
        post.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


# Likes.

class LikeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request: Request, post_id: int) -> Response:
        if not PostModel.objects.filter(pk=post_id).exists():
            return Response({"detail": "No encontrado."}, status=404)
        PostLikeModel.objects.get_or_create(post_id=post_id, user=request.user)
        return Response(self._state(post_id, request.user.pk, liked=True))

    def delete(self, request: Request, post_id: int) -> Response:
        PostLikeModel.objects.filter(post_id=post_id, user=request.user).delete()
        return Response(self._state(post_id, request.user.pk, liked=False))

    @staticmethod
    def _state(post_id: int, me_id: int, liked: bool) -> dict:
        return {
            "liked_by_me": liked,
            "like_count": PostLikeModel.objects.filter(post_id=post_id).count(),
        }


# Comments.

class CommentListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request: Request, post_id: int) -> Response:
        comments = (
            CommentModel.objects.filter(post_id=post_id).select_related("author")
        )
        return Response([_comment(c) for c in comments])

    def post(self, request: Request, post_id: int) -> Response:
        if not PostModel.objects.filter(pk=post_id).exists():
            return Response({"detail": "No encontrado."}, status=404)
        text = (request.data.get("text") or "").strip()
        if not text:
            return Response({"detail": "El comentario está vacío."}, status=400)
        c = CommentModel.objects.create(
            post_id=post_id, author=request.user, text=text
        )
        return Response(_comment(c), status=status.HTTP_201_CREATED)


# Users: search and follow.

class UserSearchView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        me = request.user.pk
        q = (request.query_params.get("q") or "").strip()
        qs = UserModel.objects.exclude(pk=me)
        if q:
            qs = qs.filter(Q(name__icontains=q) | Q(email__icontains=q))
        qs = qs[:30]

        following_ids = set(
            FollowModel.objects.filter(follower_id=me).values_list(
                "following_id", flat=True
            )
        )
        return Response([
            {
                **_author(u),
                "is_following": u.id in following_ids,
                "follower_count": FollowModel.objects.filter(following_id=u.id).count(),
            }
            for u in qs
        ])


class UserProfileDetailView(APIView):
    """A user's profile: basics always; progress + posts only if public or it's
    the user themselves."""
    permission_classes = [IsAuthenticated]

    def get(self, request: Request, user_id: int) -> Response:
        target = (
            UserModel.objects.select_related("profile").filter(pk=user_id).first()
        )
        if target is None:
            return Response({"detail": "Usuario no encontrado."}, status=404)

        me = request.user.pk
        is_me = user_id == me
        public = _is_public(target)
        visible = public or is_me

        data = {
            **_author(target),
            "is_me": is_me,
            "is_public": public,
            "is_following": FollowModel.objects.filter(
                follower_id=me, following_id=user_id
            ).exists(),
            "follower_count": FollowModel.objects.filter(following_id=user_id).count(),
            "following_count": FollowModel.objects.filter(follower_id=user_id).count()
            if visible else None,
            "post_count": PostModel.objects.filter(author_id=user_id).count()
            if visible else None,
            "stats": _user_stats(user_id) if visible else None,
            "posts": [
                _post(p, request, me)
                for p in _POST_QS().filter(author_id=user_id)[:30]
            ] if visible else None,
        }
        return Response(data)


class FollowView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request: Request, user_id: int) -> Response:
        if user_id == request.user.pk:
            return Response({"detail": "No puedes seguirte a ti mismo."}, status=400)
        if not UserModel.objects.filter(pk=user_id).exists():
            return Response({"detail": "Usuario no encontrado."}, status=404)
        FollowModel.objects.get_or_create(
            follower=request.user, following_id=user_id
        )
        return Response({"is_following": True}, status=status.HTTP_200_OK)

    def delete(self, request: Request, user_id: int) -> Response:
        FollowModel.objects.filter(
            follower=request.user, following_id=user_id
        ).delete()
        return Response({"is_following": False}, status=status.HTTP_200_OK)
