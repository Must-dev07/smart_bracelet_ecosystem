"""Bracelet CRUD, pairing lifecycle & history tests."""
import pytest

from bracelets.models import Pairing
from tests.factories import BabyFactory, BraceletFactory

pytestmark = pytest.mark.django_db


def test_register_and_pair_bracelet(parent, parent_client):
    baby = BabyFactory(parent=parent)
    resp = parent_client.post(
        "/api/v1/bracelets/", {"serial_number": "SB-TEST-001", "firmware_version": "1.0.0"},
        format="json",
    )
    assert resp.status_code == 201
    bracelet_id = resp.data["id"]

    resp = parent_client.post(
        f"/api/v1/bracelets/{bracelet_id}/pair/", {"baby_id": baby.id}, format="json"
    )
    assert resp.status_code == 201
    assert Pairing.objects.filter(bracelet_id=bracelet_id, baby=baby, unpaired_at__isnull=True).exists()


def test_pairing_history_preserved_on_repair(parent, parent_client):
    baby1 = BabyFactory(parent=parent)
    baby2 = BabyFactory(parent=parent)
    bracelet = BraceletFactory()

    parent_client.post(f"/api/v1/bracelets/{bracelet.id}/pair/", {"baby_id": baby1.id}, format="json")
    parent_client.post(f"/api/v1/bracelets/{bracelet.id}/pair/", {"baby_id": baby2.id}, format="json")

    pairings = Pairing.objects.filter(bracelet=bracelet)
    assert pairings.count() == 2
    assert pairings.filter(unpaired_at__isnull=True).count() == 1  # only one open
    bracelet.refresh_from_db()
    assert bracelet.baby_id == baby2.id


def test_unpair(parent, parent_client):
    baby = BabyFactory(parent=parent)
    bracelet = BraceletFactory()
    parent_client.post(f"/api/v1/bracelets/{bracelet.id}/pair/", {"baby_id": baby.id}, format="json")
    resp = parent_client.post(f"/api/v1/bracelets/{bracelet.id}/unpair/")
    assert resp.status_code == 200
    bracelet.refresh_from_db()
    assert bracelet.baby is None
    assert bracelet.status == "inactive"


def test_parent_cannot_pair_with_foreign_baby(parent_client):
    foreign_baby = BabyFactory()  # someone else's baby
    bracelet = BraceletFactory()
    resp = parent_client.post(
        f"/api/v1/bracelets/{bracelet.id}/pair/", {"baby_id": foreign_baby.id}, format="json"
    )
    assert resp.status_code == 403


def test_only_admin_deletes_bracelets(parent_client, admin_client):
    bracelet = BraceletFactory()
    resp = parent_client.delete(f"/api/v1/bracelets/{bracelet.id}/")
    assert resp.status_code == 403
    resp = admin_client.delete(f"/api/v1/bracelets/{bracelet.id}/")
    assert resp.status_code == 204


def test_battery_validation(parent_client):
    resp = parent_client.post(
        "/api/v1/bracelets/", {"serial_number": "SB-X", "battery_level": 150}, format="json"
    )
    assert resp.status_code == 400
