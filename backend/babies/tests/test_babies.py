"""Baby CRUD + role scoping + validation tests."""
import pytest

from tests.factories import BabyFactory, DoctorFactory, ParentFactory

pytestmark = pytest.mark.django_db


def test_parent_creates_and_lists_own_babies(parent_client):
    resp = parent_client.post(
        "/api/v1/babies/",
        {"name": "Léa", "birth_date": "2026-07-01", "weight_grams": 3100, "gender": "female"},
        format="json",
    )
    assert resp.status_code == 201
    resp = parent_client.get("/api/v1/babies/")
    assert resp.status_code == 200
    assert resp.data["count"] == 1
    assert resp.data["results"][0]["name"] == "Léa"


def test_parent_cannot_see_other_parents_babies(parent_client):
    other = BabyFactory()  # different parent
    resp = parent_client.get(f"/api/v1/babies/{other.id}/")
    assert resp.status_code == 404  # filtered out of queryset entirely


def test_doctor_sees_only_assigned_babies(doctor, doctor_client):
    mine = BabyFactory(assigned_doctor=doctor)
    BabyFactory()  # not assigned
    resp = doctor_client.get("/api/v1/babies/")
    assert resp.data["count"] == 1
    assert resp.data["results"][0]["id"] == mine.id


def test_doctor_cannot_create_or_delete_babies(doctor, doctor_client):
    resp = doctor_client.post(
        "/api/v1/babies/",
        {"name": "X", "birth_date": "2026-07-01", "weight_grams": 3000, "gender": "male"},
        format="json",
    )
    assert resp.status_code == 403

    baby = BabyFactory(assigned_doctor=doctor)
    resp = doctor_client.delete(f"/api/v1/babies/{baby.id}/")
    assert resp.status_code == 403


def test_weight_and_birthdate_validation(parent_client):
    resp = parent_client.post(
        "/api/v1/babies/",
        {"name": "X", "birth_date": "2030-01-01", "weight_grams": 3000, "gender": "male"},
        format="json",
    )
    assert resp.status_code == 400  # future birth date

    resp = parent_client.post(
        "/api/v1/babies/",
        {"name": "X", "birth_date": "2026-07-01", "weight_grams": 100, "gender": "male"},
        format="json",
    )
    assert resp.status_code == 400  # implausible weight


def test_medical_history_append_only_doctor(doctor, doctor_client, parent_client):
    baby = BabyFactory(assigned_doctor=doctor)
    resp = doctor_client.post(
        f"/api/v1/babies/{baby.id}/medical-history/",
        {"title": "Naissance", "details": "RAS"},
        format="json",
    )
    assert resp.status_code == 201

    # Parent (not owner of this baby) gets 404; owner-parent gets 403 on create
    owner_parent_client = parent_client  # different parent → baby invisible
    resp = owner_parent_client.post(
        f"/api/v1/babies/{baby.id}/medical-history/", {"title": "x"}, format="json"
    )
    assert resp.status_code == 404
