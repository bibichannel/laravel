#!/bin/bash
set -ex

export REMOTE=$1
export REPO=$2

sed -i 's/^REMOTE_BRANCH.*/REMOTE_BRANCH='$REMOTE'/' $(pwd)/.env
sed -i 's/^REPO_BRANCH.*/REPO_BRANCH='$REPO'/' $(pwd)/.env

source .env

# Clone project
git clone -b $REMOTE_BRANCH ${REPO_CLONE} ${REPO_BRANCH}_${REPOSITORY_NAME}

# ssh database server create user: backup restore
sudo docker exec postgres sh -c "psql postgres -tc \"SELECT 1 FROM pg_user WHERE usename = '${DB_USERNAME}'\" | grep -q 1 || psql postgres -c \"CREATE USER ${DB_USERNAME} WITH CREATEROLE CREATEDB PASSWORD '${DB_PASSWORD}'\""
sudo docker exec postgres sh -c "pg_dump -U root project > backup.sql"
sudo docker exec postgres sh -c "psql postgres -tc \"SELECT 1 FROM pg_database WHERE datname = '${DB_DATABASE}'\" | grep -q 1 || createdb -U $DB_USERNAME -T template0 $DB_DATABASE"

#docker exec laravel_db_1 createdb -U $DB_USERNAME -T template0 $DB_DATABASE
sudo docker exec postgres psql -U $DB_USERNAME $DB_DATABASE -f backup.sql
sudo docker exec postgres sh -c 'echo "\l" | psql postgres'
sudo docker exec postgres sh -c 'echo "\du" | psql postgres'

echo "ACCESS ADMINER: 'http://127.0.0.1:8080'"
echo "DATABASE NAME: ${DB_DATABASE}"
echo "USER NAME: ${DB_USERNAME}"
echo "PASSWORD: ${DB_PASSWORD}"

cp $(pwd)/${REPO_BRANCH}_${REPOSITORY_NAME}/.env.example $(pwd)/${REPO_BRANCH}_${REPOSITORY_NAME}/.env
export DATABASE_IP=`sudo docker inspect -f  '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' postgres`
sed -i 's/^DB_HOST.*/DB_HOST='$DATABASE_IP'/' $(pwd)/${REPO_BRANCH}_${REPOSITORY_NAME}/.env
sed -i 's/^DB_PORT.*/DB_PORT='$DB_PORT/'' $(pwd)/${REPO_BRANCH}_${REPOSITORY_NAME}/.env
sed -i 's/^DB_DATABASE.*/DB_DATABASE='$DB_DATABASE'/' $(pwd)/${REPO_BRANCH}_${REPOSITORY_NAME}/.env
sed -i 's/^DB_USERNAME.*/DB_USERNAME='$DB_USERNAME'/' $(pwd)/${REPO_BRANCH}_${REPOSITORY_NAME}/.env
sed -i 's/^DB_PASSWORD.*/DB_PASSWORD='$DB_PASSWORD'/' $(pwd)/${REPO_BRANCH}_${REPOSITORY_NAME}/.env
sed -i 's/^DB_CONNECTION.*/DB_CONNECTION='$DB_CONNECTION'/' $(pwd)/${REPO_BRANCH}_${REPOSITORY_NAME}/.env

sudo chmod 777 $(pwd)/${REPO_BRANCH}_${REPOSITORY_NAME}/storage/*
sudo chmod 777 $(pwd)/${REPO_BRANCH}_${REPOSITORY_NAME}/storage/framework/*
sudo chmod 777 $(pwd)/${REPO_BRANCH}_${REPOSITORY_NAME}/bootstrap/*

sudo docker run --rm -v $(pwd)/${REPO_BRANCH}_${REPOSITORY_NAME}:/var/www/html bibichannel/laravel:v1 sh -c "composer install; php artisan key:generate"
sudo docker-compose up

sudo docker exec postgres dropdb ${DB_DATABASE}
sudo docker exec postgres dropuser ${DB_USERNAME}
sudo rm -rf ${REPO_BRANCH}_${REPOSITORY_NAME} 
