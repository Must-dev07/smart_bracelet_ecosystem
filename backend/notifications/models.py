"""Notification records + per-user device tokens for FCM push delivery."""
from django.conf import settings
from django.db import models

from alerts.models import Alert


class DeviceToken(models.Model):
    """FCM registration token registered by the mobile app after login."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="device_tokens")
    token = models.CharField(max_length=512, unique=True)
    platform = models.CharField(max_length=16, default="android")  # android|ios|web
    created_at = models.DateTimeField(auto_now_add=True)


class Notification(models.Model):
    class Channel(models.TextChoices):
        PUSH = "push"
        SMS = "sms"
        EMAIL = "email"

    class Status(models.TextChoices):
        PENDING = "pending"
        SENT = "sent"
        FAILED = "failed"
        READ = "read"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications")
    alert = models.ForeignKey(Alert, null=True, blank=True, on_delete=models.CASCADE, related_name="notifications")
    channel = models.CharField(max_length=8, choices=Channel.choices, default=Channel.PUSH)
    title = models.CharField(max_length=128)
    body = models.CharField(max_length=512)
    status = models.CharField(max_length=8, choices=Status.choices, default=Status.PENDING)
    sent_at = models.DateTimeField(null=True, blank=True)
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-created_at"]
