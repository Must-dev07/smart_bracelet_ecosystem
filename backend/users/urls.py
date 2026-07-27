from django.urls import path

from .views import DoctorDetailView, DoctorListView, MeView, ParentDetailView, UserListView

urlpatterns = [
    path("me/", MeView.as_view(), name="me"),
    path("users/", UserListView.as_view(), name="user-list"),
    path("doctors/", DoctorListView.as_view(), name="doctor-list"),
    path("doctors/<int:pk>/", DoctorDetailView.as_view(), name="doctor-detail"),
    path("parents/<int:pk>/", ParentDetailView.as_view(), name="parent-detail"),
]
