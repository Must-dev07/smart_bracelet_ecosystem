from django.urls import path

from .views import BabyDetailView, BabyListCreateView, MedicalHistoryListCreateView

urlpatterns = [
    path("", BabyListCreateView.as_view(), name="baby-list"),
    path("<int:pk>/", BabyDetailView.as_view(), name="baby-detail"),
    path("<int:baby_id>/medical-history/", MedicalHistoryListCreateView.as_view(), name="baby-medical-history"),
]
