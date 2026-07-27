from django.urls import path

from .views import DeviceTokenRegisterView, NotificationListView, NotificationReadView

urlpatterns = [
    path("", NotificationListView.as_view(), name="notification-list"),
    path("<int:pk>/read/", NotificationReadView.as_view(), name="notification-read"),
    path("device-tokens/", DeviceTokenRegisterView.as_view(), name="device-token-register"),
]
