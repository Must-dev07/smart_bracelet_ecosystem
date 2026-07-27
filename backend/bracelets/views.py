"""Bracelet CRUD + pair/unpair actions with full history."""
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from common.permissions import IsDoctorOrAdmin, user_can_access_baby
from .models import Bracelet, Pairing
from .serializers import BraceletSerializer, PairingSerializer, PairRequestSerializer


def bracelets_for(user):
    qs = Bracelet.objects.select_related("baby")
    if user.role == "admin":
        return qs
    if user.role == "doctor":
        return qs.filter(baby__assigned_doctor__user=user)
    # Parents see bracelets paired with their babies + unassigned ones (to pair)
    return qs.filter(baby__parent__user=user) | qs.filter(baby__isnull=True)


class BraceletListCreateView(generics.ListCreateAPIView):
    serializer_class = BraceletSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return bracelets_for(self.request.user).distinct().order_by("id")

    def perform_create(self, serializer):
        # Any authenticated user can register a bracelet they own (serial from box).
        serializer.save()


class BraceletDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = BraceletSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return bracelets_for(self.request.user).distinct()

    def perform_destroy(self, instance):
        if self.request.user.role != "admin":
            from rest_framework.exceptions import PermissionDenied

            raise PermissionDenied("Only admins can delete bracelets.")
        instance.delete()


class PairView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        bracelet = generics.get_object_or_404(
            bracelets_for(request.user).distinct(), pk=pk
        )
        serializer = PairRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        baby = serializer.validated_data["baby"]
        if not user_can_access_baby(request.user, baby):
            return Response({"detail": "You cannot pair with this baby."}, status=403)
        pairing = bracelet.pair_with(baby)
        return Response(PairingSerializer(pairing).data, status=status.HTTP_201_CREATED)


class UnpairView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        bracelet = generics.get_object_or_404(
            bracelets_for(request.user).distinct(), pk=pk
        )
        if bracelet.baby and not user_can_access_baby(request.user, bracelet.baby):
            return Response({"detail": "Forbidden."}, status=403)
        bracelet.unpair()
        return Response({"detail": "Unpaired."})


class PairingHistoryView(generics.ListAPIView):
    """Doctor/admin view of a bracelet's full pairing history."""

    serializer_class = PairingSerializer
    permission_classes = [IsDoctorOrAdmin]

    def get_queryset(self):
        return Pairing.objects.filter(bracelet_id=self.kwargs["pk"]).select_related("baby")
