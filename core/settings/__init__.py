import environ
from .deploy import *

env = environ.Env()
environ.Env.read_env(f'{BASE_DIR}/.env')
SECRET_KEY = env('SECRET_KEY')

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'USER': env('POSTGRES_USER'),
        'PASSWORD': env('POSTGRES_PASSWORD'),
        'NAME': env('POSTGRES_DB'),
        'HOST': 'postgres',
        'PORT': '5432'
    }
}

# CACHES = {
#     'default': {
#         'BACKEND': 'django.core.cache.backends.redis.RedisCache',
#         'LOCATION': 'redis://127.0.0.1:6379',
#         'TIMEOUT': 900
#     }
# }



STATIC_URL = 'static/'
STATICFILES_DIRS = [
    BASE_DIR/'static',
]
STATIC_ROOT = '/var/www/static/'

# SESSION_COOKIE_SECURE=True
# CSRF_COOKIE_SECURE=True
# SECURE_HSTS_SECONDS=31536000
# SECURE_HSTS_INCLUDE_SUBDOMAINS=True
# SECURE_HSTS_PRELOAD=True
# SECURE_SSL_REDIRECT=True
# SECURE_PEFRRER_POLICY="strict-origin"
# SECURE_BROWSER_XSS_FILTER=True
