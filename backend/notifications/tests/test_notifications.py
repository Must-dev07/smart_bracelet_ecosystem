"""Notification list/read + device token registration tests."""
import pytest
from django.utils import timezone

from notifications.models import DeviceToken, Notification

pytestmark = pytest.mark.django_db


def make_notification(user, **kw):
    defaults = dict(user=user, title="T", body="B", channel="push", status="sent",
                    sent_at=timezone.now())
    defaults.update(kw)
    return Notification.objects.create(**defaults)


def test_list_own_notifications_only(parent, parent_client, doctor):
    make_notification(parent.user)
    make_notification(doctor.user)
    resp = parent_client.get("/api/v1/notifications/")
    assert resp.status_code == 200
    assert resp.data["count"] == 1


def test_unread_filter_and_mark_read(parent, parent_client):
    n = make_notification(parent.user)
    resp = parent_client.get("/api/v1/notifications/", {"unread": "true"})
    assert resp.data["count"] == 1
    resp = parent_client.post(f"/api/v1/notifications/{n.id}/read/")
    assert resp.status_code == 200
    resp = parent_client.get("/api/v1/notifications/", {"unread": "true"})
    assert resp.data["count"] == 0


def test_cannot_read_foreign_notification(parent_client, doctor):
    n = make_notification(doctor.user)
    resp = parent_client.post(f"/api/v1/notifications/{n.id}/read/")
    assert resp.status_code == 404


def test_device_token_upsert_and_delete(parent, parent_client):
    resp = parent_client.post(
        "/api/v1/notifications/device-tokens/",
        {"token": "fcm-token-abc", "platform": "android"}, format="json",
    )
    assert resp.status_code == 201
    # Same token re-registered → idempotent (still 1 row)
    parent_client.post(
        "/api/v1/notifications/device-tokens/",
        {"token": "fcm-token-abc", "platform": "android"}, format="json",
    )
    assert DeviceToken.objects.count() == 1

    resp = parent_client.delete(
        "/api/v1/notifications/device-tokens/", {"token": "fcm-token-abc"}, format="json"
    )
    assert resp.status_code == 204
    assert DeviceToken.objects.count() == 0
