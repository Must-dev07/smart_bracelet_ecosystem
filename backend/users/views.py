"""Doctor/Parent profile endpoints + admin user listing for the dashboard."""
from rest_framework import generics, permissions

from common.permissions import IsAdmin
from .models import Doctor, Parent, User
from .serializers import DoctorSerializer, ParentSerializer, UserSummarySerializer


class IsSelfOrAdmin(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        return request.user.role == "admin" or obj.user_id == request.user.id


class DoctorDetailView(generics.RetrieveUpdateAPIView):
    queryset = Doctor.objects.select_related("user")
    serializer_class = DoctorSerializer
    permission_classes = [permissions.IsAuthenticated, IsSelfOrAdmin]


class ParentDetailView(generics.RetrieveUpdateAPIView):
    queryset = Parent.objects.select_related("user")
    serializer_class = ParentSerializer
    permission_classes = [permissions.IsAuthenticated, IsSelfOrAdmin]


class DoctorListView(generics.ListAPIView):
    """Used by admin (dashboard user management) and to assign doctors."""

    queryset = Doctor.objects.select_related("user").order_by("id")
    serializer_class = DoctorSerializer
    permission_classes = [permissions.IsAuthenticated]


class UserListView(generics.ListAPIView):
    """Admin-only: full user list for the dashboard Users page."""

    queryset = User.objects.order_by("id")
    serializer_class = UserSummarySerializer
    permission_classes = [IsAdmin]


class MeView(generics.RetrieveAPIView):
    serializer_class = UserSummarySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user
