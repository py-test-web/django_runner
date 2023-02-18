#!/bin/bash


# ---------------------------------------
bash -c "source $(find . -path "*/bin/activate")"
# ---------------------------------------


# --------------- PART 1 ----------------
# Do the following tasks by User
cat <<EOF
Do the following tasks one by one.(in file settings

------------------------
1.SET .env 
ENV_NAME=Production
DEBUG=False
------------------------
4.Set IP server in ALLOWED_HOSTS and after set https replace whit domain
------------------------
EOF


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


read -p "ssh port server?[22]" ssh_port
ssh_port=${ssh_port:-22}


echo "server address(root@ip)?" 
read -r server_address

server_address=root@192.168.56.101

scp -P "$ssh_port" ./deploy.sh "$server_address":/root
ssh -p "$ssh_port"  -t "$server_address" "sh ./deploy.sh; bash"
