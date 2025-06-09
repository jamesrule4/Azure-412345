from django.contrib import admin
from django.urls import path
from django.contrib.auth import views as auth_views
from django.http import HttpResponse

def home_view(request):
    return HttpResponse("""
    <h1>Rule4 POC Django Application</h1>
    <p>Welcome to the Rule4 POC environment!</p>
    <p><a href='/admin/'>Django Admin Panel</a></p>
    <p>This application uses LDAP authentication with Active Directory.</p>
    """)

urlpatterns = [
    path('admin/', admin.site.urls),
    path('login/', auth_views.LoginView.as_view(), name='login'),
    path('logout/', auth_views.LogoutView.as_view(), name='logout'),
    path('', home_view, name='home'),
] 