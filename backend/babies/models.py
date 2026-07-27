"""Baby + append-only MedicalHistory entries."""
from django.db import models

from users.models import Doctor, Parent


class Baby(models.Model):
    class Gender(models.TextChoices):
        MALE = "male"
        FEMALE = "female"
        UNSPECIFIED = "unspecified"

    name = models.CharField(max_length=100)
    birth_date = models.DateField()
    weight_grams = models.PositiveIntegerField(help_text="Birth/current weight in grams")
    gender = models.CharField(max_length=12, choices=Gender.choices, default=Gender.UNSPECIFIED)
    parent = models.ForeignKey(Parent, on_delete=models.CASCADE, related_name="babies")
    assigned_doctor = models.ForeignKey(
        Doctor, null=True, blank=True, on_delete=models.SET_NULL, related_name="patients"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = "babies"

    def __str__(self) -> str:  # pragma: no cover
        return self.name


class MedicalHistoryEntry(models.Model):
    """Append-only medical history: entries are never edited or deleted via the
    API; corrections are made by appending a new entry referencing the old one."""

    baby = models.ForeignKey(Baby, on_delete=models.CASCADE, related_name="medical_history")
    title = models.CharField(max_length=200)
    details = models.TextField(blank=True)
    recorded_by = models.ForeignKey(Doctor, null=True, on_delete=models.SET_NULL)
    supersedes = models.ForeignKey("self", null=True, blank=True, on_delete=models.SET_NULL)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name_plural = "medical history entries"
