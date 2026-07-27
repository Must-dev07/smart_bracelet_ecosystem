"""Baby CRUD, scoped by role:
- parent: only their own babies (create allowed)
- doctor: only babies assigned to them (read + limited update)
- admin: everything
"""
from rest_framework import generics, permissions
from rest_framework.exceptions import PermissionDenied

from common.permissions import IsParentOfBabyOrAssignedDoctorOrAdmin
from .models import Baby, MedicalHistoryEntry
from .serializers import BabySerializer, MedicalHistoryEntrySerializer


def babies_for(user):
    qs = Baby.objects.select_related("parent__user", "assigned_doctor__user").prefetch_related(
        "medical_history"
    )
    if user.role == "admin":
        return qs
    if user.role == "doctor":
        return qs.filter(assigned_doctor__user=user)
    return qs.filter(parent__user=user)


class BabyListCreateView(generics.ListCreateAPIView):
    serializer_class = BabySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return babies_for(self.request.user).order_by("id")

    def perform_create(self, serializer):
        user = self.request.user
        if user.role != "parent":
            raise PermissionDenied("Only parents can register a baby.")
        serializer.save(parent=user.parent_profile)


class BabyDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = BabySerializer
    permission_classes = [
        permissions.IsAuthenticated,
        IsParentOfBabyOrAssignedDoctorOrAdmin,
    ]

    def get_queryset(self):
        return babies_for(self.request.user)

    def perform_destroy(self, instance):
        if self.request.user.role == "doctor":
            raise PermissionDenied("Doctors cannot delete patient records.")
        instance.delete()


class MedicalHistoryListCreateView(generics.ListCreateAPIView):
    """Append-only medical history. Doctors (assigned) and admins can append."""

    serializer_class = MedicalHistoryEntrySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_baby(self):
        baby = generics.get_object_or_404(babies_for(self.request.user), pk=self.kwargs["baby_id"])
        return baby

    def get_queryset(self):
        return MedicalHistoryEntry.objects.filter(baby=self.get_baby())

    def perform_create(self, serializer):
        user = self.request.user
        baby = self.get_baby()  # 404 first if the baby is out of scope (no data leak)
        if user.role not in ("doctor", "admin"):
            raise PermissionDenied("Only doctors or admins can add medical history.")
        doctor = getattr(user, "doctor_profile", None)
        serializer.save(baby=baby, recorded_by=doctor)
