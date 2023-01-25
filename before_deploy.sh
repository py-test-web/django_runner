#!/bin/bash


# ---------------------------------------

read -p "directory name virtualenv[env]: " dir_env
dir_env=${dir_env:-env}


# active virtualenv
.  "${dir_env}"/bin/activate
# ---------------------------------------


# --------------- PART 1 ----------------
# Do the following tasks by User
cat <<EOF
Do the following tasks one by one.(in file settings

------------------------
1.SET
DEBUG=False
------------------------
2.REMOVE value dictionary databases
DATABASE={
    'default':{
        .....
    }
------------------------
3.CREATE value dictionary logging in settings.py and change
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "filters": {

    },
    "formatters": {
        'formatter_django_1': {
            'format': '{name} {levelname} {asctime} {module} {message}',
            'style': '{'
        }
    },
    "handlers": {
        'handler_home': {
            'class': 'logging.FileHandler',
            'filename': 'logs/home.log',
            'formatter': 'formatter_django_1'
        },
        'handler_celery': {
            'class': 'logging.handlers.TimedRotatingFileHandler',
            'filename': 'logs/celery.log',
            'formatter': 'formatter_django_1',
        }
    },
    "loggers": {
        'logger_<app>': {
            'handlers': ['handler_home'],
            'level': 'DEBUG',
            'propagate': False,
        },
        'logger_celery': {
            'handlers': ['handler_celery'],
            'level': 'DEBUG',
        }
    },
}
------------------------
4.Set IP server in ALLOWED_HOSTS and after set https replace whit domain
------------------------
5.Remove line STATIC_URL and STATIC_ROOT
--------------------------
6.SET
  EMAIL_BACKEND
  EMAIL_HOST
  EMAIL_HOST_USER
  EMAIL_HOST_PASSWORD
-----------------------------
7.SET
  MEDIA_ROOT
  MEDIA_URL
-----------------------------
8.SET
  CONN_MAX_AGE=None
  CONN_HEALTH_CHECKS=True
------------------------------
9.Report message
ADMINS=[('fullname','email')]
MANAGERS
-----------------------------
10.CREATE Template Error
  400.html
  403.html
  404.html
  500.html
------------------------------
EOF


# --------------- PART 2 ----------------
# Config Settings
read -p "directory name project?[core]: " dir_project
dir_project=${dir_project:-core}
cd "$dir_project" || exist
mkdir settings/
mv settings.py ./settings/deploy.py
cd settings/ || exist
touch __init__.py
cat >__init__.py <<EOF 
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
STATIC_ROOT = '/var/www/static/'

# SESSION_COOKIE_SECURE=True
# CSRF_COOKIE_SECURE=True
# SECURE_HSTS_SECONDS=31536000
# SECURE_HSTS_INCLUDE_SUBDOMAINS=True
# SECURE_HSTS_PRELOAD=True
# SECURE_SSL_REDIRECT=True
# SECURE_PEFRRER_POLICY="strict-origin"
# SECURE_BROWSER_XSS_FILTER=True
EOF
# ---------------------------------------
cd ../..
# ---------------------------------------


# --------------- PART 4 ----------------
cat <<EOF
install :
        - gunicorn
        - django-environ
        - psycopg2-binary
        - redis
        - hiredis

craete requirements.txt
EOF
pip install django-environ
pip install psycopg2-binary
# pip install redis
# pip install hiredis
pip install gunicorn
pip freeze > requirements.txt
# ---------------------------------------




cat <<EOF
push files to remote repository
help : 
    git add .
    git commit -m "ready to deploy"
    git remote add origin <remote address>
    git push -u origin main
EOF


read -p "you must do tasks git And Press [ENTER] to continue" name
$name


read -p "ssh port server?[22]" ssh_port
ssh_port=${ssh_port:-22}


echo "server address(root@ip)?" 
read -r server_address

server_address=root@192.168.56.101

scp -P "$ssh_port" ./deploy.sh "$server_address":/root
ssh -p "$ssh_port"  -t "$server_address" "sh ./deploy.sh; bash"
