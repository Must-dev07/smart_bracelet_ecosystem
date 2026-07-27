from rest_framework import serializers

from bracelets.models import Bracelet
from .models import Alert


class AlertSerializer(serializers.ModelSerializer):
    baby_name = serializers.CharField(source="baby.name", read_only=True)
    disclaimer = serializers.SerializerMethodField()

    class Meta:
        model = Alert
        fields = [
            "id", "baby", "baby_name", "bracelet", "type", "severity", "message",
            "value", "triggered_at", "resolved_at", "acknowledged_by",
            "acknowledged_at", "disclaimer",
        ]
        read_only_fields = fields

    def get_disclaimer(self, obj) -> str:
        # Section 0 rule 10 — surfaced with every alert payload.
        return (
            "This alert flags an abnormal reading for caregiver or medical "
            "follow-up. It is not a medical diagnosis."
        )


class BleLostReportSerializer(serializers.Serializer):
    bracelet_id = serializers.PrimaryKeyRelatedField(
        queryset=Bracelet.objects.all(), source="bracelet"
    )
