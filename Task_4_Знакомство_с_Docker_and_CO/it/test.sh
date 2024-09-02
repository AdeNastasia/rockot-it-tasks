    apt update &&\
    apt -y install --no-install-recommends \
        apache2 \
        nano \
        vim-tiny &&\
    apt clean &&\
    rm -rf /var/lib/apt/lists/*
