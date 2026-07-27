"""Profile endpoints + admin-only user list tests."""
import pytest

pytestmark = pytest.mark.django_db


def test_me_endpoint(parent_client, parent):
    resp = parent_client.get("/api/v1/me/")
    assert resp.status_code == 200
    assert resp.data["email"] == parent.user.email
    assert resp.data["role"] == "parent"


def test_doctor_updates_own_profile(doctor, doctor_client):
    resp = doctor_client.put(
        f"/api/v1/doctors/{doctor.id}/",
        {"user": {"first_name": "New", "last_name": "Name", "phone": "+33611111111"},
         "license_number": doctor.license_number, "specialty": "Pediatrics"},
        format="json",
    )
    assert resp.status_code == 200
    doctor.refresh_from_db()
    assert doctor.specialty == "Pediatrics"
    assert doctor.user.first_name == "New"


def test_parent_cannot_edit_foreign_doctor(parent_client, doctor):
    resp = parent_client.put(
        f"/api/v1/doctors/{doctor.id}/",
        {"user": {"first_name": "Hack"}, "license_number": "X", "specialty": "X"},
        format="json",
    )
    assert resp.status_code == 403


def test_user_list_admin_only(parent_client, admin_client):
    resp = parent_client.get("/api/v1/users/")
    assert resp.status_code == 403
    resp = admin_client.get("/api/v1/users/")
    assert resp.status_code == 200


def test_audit_log_written_on_sensitive_access(parent_client, baby):
    from common.models import AuditLog

    parent_client.get("/api/v1/babies/")
    assert AuditLog.objects.filter(path="/api/v1/babies/").exists()
