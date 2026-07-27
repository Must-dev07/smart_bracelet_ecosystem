"""Alert list/filter/acknowledge + notification fan-out tests."""
import pytest
from django.utils import timezone

from alerts.models import Alert
from notifications.models import Notification

pytestmark = pytest.mark.django_db


def make_alert(baby, bracelet, **kw):
    defaults = dict(
        baby=baby, bracelet=bracelet, type=Alert.Type.HIGH_TEMP,
        severity=Alert.Severity.CRITICAL, message="Temp flagged", triggered_at=timezone.now(),
    )
    defaults.update(kw)
    return Alert.objects.create(**defaults)


def test_parent_lists_own_alerts_with_disclaimer(parent_client, baby, bracelet):
    make_alert(baby, bracelet)
    resp = parent_client.get("/api/v1/alerts/")
    assert resp.status_code == 200
    assert resp.data["count"] == 1
    assert "not a medical diagnosis" in resp.data["results"][0]["disclaimer"]


def test_status_filter(parent_client, baby, bracelet):
    make_alert(baby, bracelet)
    make_alert(baby, bracelet, type=Alert.Type.LOW_HR, resolved_at=timezone.now())
    resp = parent_client.get("/api/v1/alerts/", {"status": "active"})
    assert resp.data["count"] == 1
    resp = parent_client.get("/api/v1/alerts/", {"status": "resolved"})
    assert resp.data["count"] == 1


def test_acknowledge_resolves(parent_client, parent, baby, bracelet):
    alert = make_alert(baby, bracelet)
    resp = parent_client.post(f"/api/v1/alerts/{alert.id}/acknowledge/")
    assert resp.status_code == 200
    alert.refresh_from_db()
    assert alert.acknowledged_by == parent.user
    assert alert.resolved_at is not None


def test_foreign_alert_invisible(doctor_client, baby, bracelet):
    # doctor fixture is NOT this baby's doctor in this test setup? It is —
    # so create a baby with a different doctor to assert isolation.
    from tests.factories import BabyFactory, BraceletFactory

    other_baby = BabyFactory()
    other_bracelet = BraceletFactory()
    alert = make_alert(other_baby, other_bracelet)
    resp = doctor_client.get(f"/api/v1/alerts/{alert.id}/")
    assert resp.status_code == 404


def test_ble_lost_report(parent_client, bracelet):
    resp = parent_client.post(
        "/api/v1/alerts/report-ble-lost/", {"bracelet_id": bracelet.id}, format="json"
    )
    assert resp.status_code == 201
    assert Alert.objects.filter(type="ble_lost").count() == 1
    # Duplicate report while open → no second alert
    resp = parent_client.post(
        "/api/v1/alerts/report-ble-lost/", {"bracelet_id": bracelet.id}, format="json"
    )
    assert resp.status_code == 200
    assert Alert.objects.filter(type="ble_lost").count() == 1


def test_notification_fanout_parent_and_doctor(baby, bracelet):
    """Celery eager mode: dispatch runs inline. FCM is unconfigured in tests so
    notifications are recorded with status=failed, but rows exist for both
    the parent and the assigned doctor (severity=critical)."""
    from analysis.rules import run_rules
    from tests.factories import MeasurementFactory

    m = MeasurementFactory(baby=baby, bracelet=bracelet, spo2=85.0)
    run_rules(m)
    users = set(Notification.objects.values_list("user_id", flat=True))
    assert baby.parent.user_id in users
    assert baby.assigned_doctor.user_id in users
    body = Notification.objects.first().body
    assert "not a diagnosis" in body
