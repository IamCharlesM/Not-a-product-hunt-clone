from django.shortcuts import render
from django.contrib.auth.models import User
from django.contrib import auth

def signup(request):
    if request.method == 'POST':
        #Sign up
        if request.POST['password1'] == request.POST['password2']:
            user = User.objects.get(username=request.POST['username'])
            return render(request, 'accounts/signup.html', {'error': 'Username has already been taken.'})
        else:
            return render(request, 'accounts/signup.html')


def login(request):
   return render(request, 'accounts/login.html')


def logout(request):
    #Need to add route to homepage
   return render(request, 'accounts/signup.html')