"""Alert model — created by the analysis rule engine, acknowledged by users.

Wording note (Section 0 rule 10): alerts FLAG abnormal readings for follow-up.
They are not diagnoses; user-facing copy must reflect that.
"""
from django.conf import settings
from django.db import models

from babies.models import Baby
from bracelets.models import Bracelet


class Alert(models.Model):
    class Type(models.TextChoices):
        HIGH_TEMP = "high_temp"
        LOW_TEMP = "low_temp"
        LOW_OXYGEN = "low_oxygen"
        HIGH_HR = "high_hr"
        LOW_HR = "low_hr"
        NO_MOVEMENT = "no_movement"
        BRACELET_REMOVED = "bracelet_removed"
        BATTERY_LOW = "battery_low"
        BLE_LOST = "ble_lost"
        NO_DATA = "no_data"

    class Severity(models.TextChoices):
        INFO = "info"
        WARNING = "warning"
        CRITICAL = "critical"

    baby = models.ForeignKey(Baby, on_delete=models.CASCADE, related_name="alerts")
    bracelet = models.ForeignKey(Bracelet, null=True, on_delete=models.SET_NULL, related_name="alerts")
    type = models.CharField(max_length=24, choices=Type.choices)
    severity = models.CharField(max_length=10, choices=Severity.choices)
    message = models.CharField(max_length=255)
    value = models.FloatField(null=True, blank=True)  # the reading that triggered the rule
    triggered_at = models.DateTimeField(db_index=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    acknowledged_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL,
        related_name="acknowledged_alerts",
    )
    acknowledged_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["baby", "triggered_at"], name="alert_baby_triggered_idx"),
        ]
        ordering = ["-triggered_at"]

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.type} [{self.severity}] baby={self.baby_id}"
