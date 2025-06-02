"""URL configuration for the project."""

from django.contrib import admin
from django.urls import path
from authentication.views import login_view, logout_view, home, test_ldap

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', home, name='home'),
    path('login/', login_view, name='login'),
    path('logout/', logout_view, name='logout'),
    path('test-ldap/', test_ldap, name='test-ldap'),
] 