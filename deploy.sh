#!/bin/bash


pip install virtualenv


echo "write Address Repository(sample:git@github.com:profile/project.git)" 
read -r git_address
git clone "$git_address" /src

cd /src || exist
python3 -m virtualenv venv
. venv/bin/activate


pip install -r requirements.txt

# --------------- PART 3 ----------------
echo "create .env"
touch .env
echo "write secret_key?" 
read -r secret_key
echo "write postgres_db?" 
read -r postgres_db
echo "write postgres_user?" 
read -r postgres_user
echo "write postgres_password?" 
read -r postgres_password
cat > .env<<EOF
SECRET_KEY=$secret_key
POSTGRES_DB=$postgres_db
POSTGRES_USER=$postgres_user
POSTGRES_PASSWORD=$postgres_password
EOF
echo "Writing the .env file is finished"
# ---------------------------------------



# --------------- PART 5 ----------------
echo "Start creating the Docker file DjangoProject"
echo "directory name project?" 
read -r dir_project

touch Dockerfile
cat > Dockerfile<<EOF
FROM python:latest

WORKDIR /src
COPY requirements.txt .
RUN pip install -U pip
RUN pip install -r requirements.txt
COPY . /src
EXPOSE 8000
CMD ["gunicorn","$dir_project.wsgi",":8000"]
EOF
# ---------------------------------------


echo "Start creating nginx Dockerfile and conf"

cat >nginx.conf <<EOF 
events {}

http {
  upstream django {
      server web:8000;
  }

  server {

      listen 80;

      location / {
          proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          proxy_set_header Host \$host;
          proxy_redirect off;
          proxy_pass http://django;
      }

  }
}
EOF

# --------------- PART 7 ----------------
echo "Start creating the docker-compose file"
echo "image broker:tag?" 
read -r broker_image
echo "image db:tag?" 
read -r postgres_image
echo "image cache:tag?" 
read -r redis_image

touch docker-compose.yml
cat >docker-compose.yml <<EOF
services:
#   broker:
#     container_name: rabbitmq
#     image: $broker_image
#     ports:
#       - "5672:5672"
#     restart: on-failure
#   worker:
#     container_name: celery
#     command: "celery -A $dir_project worker -l info"
#     networks:
#      - main
#     environment:
#       - C_FORCE_ROOT='true'
#     depends_on:
#       - broker
#       - web
#       - postgres
#     build: .
#   cache:
#     container_name: redis
#     image: $redis_image
#     networks:
#       - main
#     ports:
#       - "6379:6379"
#     restart: always
  nginx:
    image: nginx:1.22.1
    container_name: nginx
    command: nginx -g 'daemon off;'
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    networks:
      - main
    ports:
      - "80:80"
    depends_on:
      - web
      - postgres
    restart: always
    links:
      - web:web
  web:
      build: .  
      container_name: web
      command: sh -c "python3 manage.py migrate && gunicorn $dir_project.wsgi -b 0.0.0.0:8000"
      volumes:
        - .:/src/
      ports:
        - "8000:8000"
      networks:
        - main
      env_file:
        - ./.env
      depends_on:
        - postgres

      restart: always
  postgres:
    container_name: postgres
    image: $postgres_image
    networks:
      - main
    volumes:
      - db_volume:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: always
    env_file: .env
    environment:
        POSTGRES_USER
        POSTGRES_PASSWORD
        POSTGRES_DB


networks:
  main:
volumes:
  db_volume:
  static_volume:
EOF

docker-compose up -d
