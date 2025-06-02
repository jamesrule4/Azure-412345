from django.contrib.auth import login, logout, authenticate
from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse
from django_auth_ldap.backend import LDAPBackend
from django.contrib import messages

def login_view(request):
    if request.user.is_authenticated:
        return redirect('home')
    return render(request, 'authentication/login.html')

def logout_view(request):
    logout(request)
    messages.success(request, 'Successfully logged out.')
    return redirect('login')

@login_required
def home(request):
    return render(request, 'authentication/home.html')

def test_ldap(request):
    return render(request, 'authentication/test_ldap.html') 