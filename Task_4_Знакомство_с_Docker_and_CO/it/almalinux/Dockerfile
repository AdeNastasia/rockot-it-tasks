FROM almalinux

LABEL maintainer="v.pukin@test.ru"

RUN yum update -y && \
    yum install httpd -y && \
    yum install nano -y && \
    yum install vim-minimal -y && \
    yum clean all && \
    rm -rf /var/cache/yum

CMD ["httpd", "-D", "FOREGROUND"]

    
