FROM nginx:1.24.0

ARG DEBIAN_FRONTEND=noninteractive

LABEL maintainer="v.pukin@test.ru"

RUN apt update &&\
    apt -y install --no-install-recommends \
        nano \
        vim-tiny &&\
    apt clean &&\
    rm -rf /var/lib/apt/lists/*

COPY default.conf /etc/nginx/conf.d/

# Образ nginx:1.24.0 сам запустит контейнер в foreground режиме
# Т.к. мы явно испольузем CMD, в последней строчке добавила включение nginx в foreground-режиме
# Выделила новую переменную для порта NGINX - API_PORT_NGINX (в .env файле) 
CMD sed -i "s/API_PORT_NGINX/${API_PORT_NGINX}/" /etc/nginx/conf.d/default.conf && \
    nginx -g 'daemon off;' 
