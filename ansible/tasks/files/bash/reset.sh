#!/usr/bin/env bash

docker login macetero.iterando.net

cd /opt/pg-cluster

docker compose stop
docker compose rm

docker volume rm -f pg-cluster_etcd-data
docker network create web

docker compose up -d
