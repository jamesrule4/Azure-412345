from django.core.management.base import BaseCommand
from django.contrib.auth.models import User

class Command(BaseCommand):
    help = 'Creates the fox admin user for demonstration'

    def handle(self, *args, **kwargs):
        if User.objects.filter(username='fox').exists():
            self.stdout.write(self.style.WARNING('User fox already exists'))
            return

        User.objects.create_superuser('fox', 'fox@rule4.local', 'Rule4SecureP0C2025!')
        self.stdout.write(self.style.SUCCESS('Successfully created fox admin user')) 