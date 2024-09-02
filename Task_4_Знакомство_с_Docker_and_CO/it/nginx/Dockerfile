FROM nginx:1.24.0

ARG DEBIAN_FRONTEND=noninteractive
ARG API_PORT
LABEL maintainer="v.pukin@test.ru"

RUN apt update &&\
    apt -y install --no-install-recommends \
        nano \
        vim-tiny &&\
    apt clean &&\
    rm -rf /var/lib/apt/lists/*

# Вопрос со звёздочкой - хочу сделать единый файл конфига для debian и centos, как?
COPY default.conf /etc/nginx/conf.d/

# Хотели менять переменную порта, но что-то не сложилось. Можно поиспользовать в проекте.
# CMD sed -i "s/API_PORT_REPLACE/${API_PORT}/" /etc/nginx/conf.d/default.conf && \
