"""
Django settings for Civic Reporting backend.
Uses environment variables for PostgreSQL and media.
"""
import os
from pathlib import Path




BASE_DIR = Path(__file__).resolve().parent.parent

# Load .env from backend folder, then project root, then cwd (so PGPASSWORD etc. are set)
try:
    from dotenv import load_dotenv
    _env_backend = BASE_DIR / ".env"
    _env_root = BASE_DIR.parent / ".env"
    if _env_backend.exists():
        load_dotenv(dotenv_path=_env_backend)
    if _env_root.exists():
        load_dotenv(dotenv_path=_env_root)
    load_dotenv()  # fallback: cwd (e.g. when run from backend/, loads backend/.env)
except ImportError:
    pass

SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'django-insecure-change-in-production')

DEBUG = os.environ.get('DJANGO_DEBUG', '1') == '1'

ALLOWED_HOSTS = ['localhost', '127.0.0.1', '10.0.2.2']

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'complaints',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'



# Database: PostgreSQL when PGPASSWORD is set, else SQLite for local development
_use_pg = os.environ.get('PGPASSWORD', '').strip()
if _use_pg:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': os.environ.get('PGDATABASE', 'civic_reporting'),
            'USER': os.environ.get('PGUSER', 'postgres'),
            'PASSWORD': _use_pg,
            'HOST': os.environ.get('PGHOST', 'localhost'),
            'PORT': os.environ.get('PGPORT', '5432'),
            'OPTIONS': {},
        }
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]



LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

# Media (uploaded complaint images)
MEDIA_URL = os.environ.get('DJANGO_MEDIA_URL', '/media/')
MEDIA_ROOT = os.environ.get('DJANGO_MEDIA_ROOT', str(BASE_DIR / 'media'))

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# CORS - allow Flutter web/mobile to call API
CORS_ALLOW_ALL_ORIGINS = DEBUG
if not CORS_ALLOW_ALL_ORIGINS:
    CORS_ALLOWED_ORIGINS = os.environ.get('CORS_ALLOWED_ORIGINS', '').split(',')

# CLIP model path (local only; do not download)
CLIP_MODEL_PATH = os.environ.get('CLIP_MODEL_PATH', '')
