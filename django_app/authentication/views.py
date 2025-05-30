from django.contrib.auth import login, logout, authenticate
from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse
from django_auth_ldap.backend import LDAPBackend

def login_view(request):
    error = None
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        user = authenticate(request, username=username, password=password)
        if user is not None:
            login(request, user)
            return redirect('home')
        error = "Invalid credentials"
    return render(request, 'authentication/login.html', {'error': error})

def logout_view(request):
    logout(request)
    return redirect('login')

@login_required
def home(request):
    return render(request, 'authentication/home.html', {
        'user': request.user,
        'groups': request.user.groups.all(),
    })

def test_ldap(request):
    try:
        backend = LDAPBackend()
        # Try to connect to LDAP server
        connection = backend.ldap.initialize(backend.settings.SERVER_URI)
        connection.set_option(backend.ldap.OPT_REFERRALS, 0)
        connection.simple_bind_s(
            backend.settings.BIND_DN,
            backend.settings.BIND_PASSWORD
        )
        return HttpResponse("LDAP Connection Successful!", content_type="text/plain")
    except Exception as e:
        return HttpResponse(f"LDAP Connection Failed: {str(e)}", content_type="text/plain", status=500) 