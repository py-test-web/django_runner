#!/bin/bash


# #########################################################
# before run this script
#   1.sudo apt install git-flow
#
#
# #########################################################

# ---------------------------------------
git flow init
git flow feature start initial
# ---------------------------------------

# ---------------------------------------
# VirtualEnviroment craete and active
pip install --upgrade virtualenv
python3 -m virtualenv venv
. ./venv/bin/activate
# ---------------------------------------


# ---------------------------------------
# Install Django
read -p "django verion [4.1.7]" django_verion
django_verion=${django_verion:-4.1.7}
pip install django=="$django_verion"
django-admin startproject core .
# ---------------------------------------


pip install django-environ
# ---------------------------------------
# create .gitignore and merge to develop branch
cat >.gitignore <<EOF 
*.log
*.pot
*.pyc
__pycache__/
db.sqlite3
media
.env
venv/
.idea/
EOF

git add . 
git commit -m "initial project"
git flow feature finish initial
# ---------------------------------------


# ---------------------------------------

read -p "Architecture api 1.REST API(drf) 2.GraphqL(graphene)  [1]" architecture_api
architecture_api=${architecture_api:-1}
read -p "select name for app account [account]" app_name_account
app_name_account=${app_name_account:-account}


# ---------------------------------------
# create app account
git flow feature start account
sh app_account.sh $architecture_api "$app_name_account"
# ---------------------------------------


# ---------------------------------------
if [ "$architecture_api" -eq 1 ]  # REST API
then
pip install djangorestframework
pip install djangorestframework-simplejwt
appnames_in_installed_app="
    'rest_framework',
    'rest_framework_simplejwt',
"
setting_architecture_api="
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    )
}
"
elif [ "$architecture_api" -eq 2 ]   # GraphQL
then
pip install graphene-django
pip install django-graphql-jwt
appnames_in_installed_app="'graphene_django',"
setting_architecture_api="
AUTHENTICATION_BACKENDS = [
    'graphql_jwt.backends.JSONWebTokenBackend',
    'django.contrib.auth.backends.ModelBackend',
]
GRAPHENE = {
    'SCHEMA': 'core.schema.my_schema',
    'MIDDLEWARE': [
        'graphql_jwt.middleware.JSONWebTokenMiddleware',
    ],
}
"
fi
# ---------------------------------------



# -----------------NEO4J----------------------
read -p "GraphDatabase Neo4j and neomodel  1.Yes  2.No[2]" is_graph_db
is_graph_db=${is_graph_db:-2}

if [ "$is_graph_db" -eq 1 ]
then

read -p "User GraphDatabase Neo4j  [neo4j]" user_neo4j
user_neo4j=${user_neo4j:-neo4j}

read -p "Password GraphDatabase Neo4j  [12345678]" password_neo4j
password_neo4j=${password_neo4j:-12345678}

env_neo4j="
NEO4J_USER=$user_neo4j
NEO4J_PASSWORD=$password_neo4j
NEO4J_BOLT_URL=bolt://$user_neo4j:$password_neo4j}@localhost:7687
"
pip install django_neomodel
docker_compose_service_neo4j='
  neo4j:
    container_name: neo4j
    image: neo4j:4.4.17
#   volumes:
#     - db_neo4j_volume:/data
    ports:
      - "7474:7474"
      - "7473:7473"
      - "7687:7687"
    restart: always
    env_file: .env
    environment:
      - NEO4J_USER
      - NEO4J_PASSWORD
'
docker_compose_volume_neo4j='db_neo4j_volume:'
settings_neo4j="
NEOMODEL_NEO4J_BOLT_URL = env('NEO4J_BOLT_URL')
NEOMODEL_SIGNALS = True
NEOMODEL_FORCE_TIMEZONE = False
NEOMODEL_ENCRYPTED_CONNECTION = True
NEOMODEL_MAX_POOL_SIZE = 50
"
elif [ "$is_graph_db" -eq 1 ]
then
env_neo4j=''
docker_compose_service_neo4j=''
docker_compose_volume_neo4j=''
settings_neo4j=''
fi
# ---------------------------------------


# ---------------------------------------
# settings directory
rm core/settings.py
cd core || exist
mkdir settings
cd settings || exist
touch __init__.py base.py local.py production.py

cat >__init__.py <<EOF
from .base import *

if env("ENV_NAME") == 'Local':
    from .local import *
elif env("ENV_NAME") == 'Production':
    from .production import *
EOF

cat >base.py <<EOF
from pathlib import Path
import environ

BASE_DIR = Path(__file__).resolve().parent.parent.parent
env = environ.Env()
environ.Env.read_env(f'{BASE_DIR}/.env')
SECRET_KEY = env('SECRET_KEY')


INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'account.apps.AccountConfig',
    $appnames_in_installed_app
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'core.urls'

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

WSGI_APPLICATION = 'core.wsgi.application'

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

AUTH_USER_MODEL = 'account.User'
TIME_REGISTER_VERIFY_CODE = 120


LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "filters": {},
    "formatters": {
        'formatter_django_1': {
            'format': '{name} {levelname} {asctime} {module} {message}',
            'style': '{'
        }
    },
    "handlers": {
        'handler_account': {
            'class': 'logging.FileHandler',
            'filename': 'logs/account.log',
            'formatter': 'formatter_django_1'
        },
        # add another handler
    },
    "loggers": {
        'logger_account': {
            'handlers': ['handler_account'],
            'level': 'DEBUG',
            'propagate': False,
        },
        # add another logger
    },
}


# EMAIL_HOST = ******
# EMAIL_PORT = ******
# EMAIL_USE_SSL = ******
# EMAIL_HOST_USER = ******
# EMAIL_HOST_PASSWORD = ******

$settings_neo4j
$setting_architecture_api
EOF

cat >local.py <<EOF
from .base import BASE_DIR


DEBUG = True
ALLOWED_HOSTS = ['*']
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'static'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

EOF

cat >production.py <<EOF
from .base import env

DEBUG = False
ALLOWED_HOSTS = ['*.*.*.*']


DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'USER': env('POSTGRES_USER'),
        'PASSWORD': env('POSTGRES_PASSWORD'),
        'NAME': env('POSTGRES_DB'),
        'HOST': '127.0.0.1',
        'PORT': '5432'
    }
}

# STATIC_URL = '/static/'
# STATIC_ROOT = BASE_DIR / 'static'
# STATICFILES_DIRS = (
#     BASE_DIR / 'static/',
# )
# MEDIA_URL = '/media/'
# MEDIA_ROOT = BASE_DIR / 'media'

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


# ---------------------------------------
cd ../..
mkdir logs
mkdir static
mkdir media
cd logs/ || exist
touch account.log
cd ../  || exist
# ---------------------------------------
# ---------------------------------------
# .env file
cat > .env <<EOF
ENV_NAME=Local
SECRET_KEY=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key());')
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
$env_neo4j
EOF
# ---------------------------------------



# ---------------------------------------
# docker-compose
cat >docker-compose.yml <<EOF
services:
  $docker_compose_service_neo4j
#   postgres:
#     container_name: postgres
#     image: postgres:latest
#   volumes:
#     - db_postgres_volume:/var/lib/postgresql/data
#    ports:
#      - "5432:5432"
#    restart: always
#    env_file: .env
#    environment:
#      - POSTGRES_USER
#      - POSTGRES_PASSWORD
#      - POSTGRES_DB
# volumes:
#   db_postgres_volume:
#   $docker_compose_volume_neo4j
  
EOF
echo "sleep for up containers docker"
sleep 10
docker-compose up -d
# ---------------------------------------


# ---------------------------------------
./manage.py makemigrations
./manage.py migrate
# ---------------------------------------

git add . 
git commit -m "create account app ,docker-compose "
git flow feature finish account
# ---------------------------------------

# read -p "remote repository " remote_repository

# git remote add origin "$remote_repository"
# git push -u origin main
# git push -u origin develope
# read -p "activate 1.code 2.link 3.link(email) or code(mobile) [2]" activate_user
# activate_user=${activate_user:-2}
