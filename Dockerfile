FROM alpine:latest

RUN apk add --no-cache \
    bash \
    curl \
    docker-cli \
    coreutils \
    findutils \
    postgresql-client \
    tzdata

WORKDIR /srv/jimflix/jimflix-scripts

COPY ./scripts ./scripts
COPY ./pollers ./pollers
COPY ./entrypoint.sh .

RUN chmod +x ./scripts/*.sh ./pollers/*.sh entrypoint.sh

ENTRYPOINT ["bash", "./entrypoint.sh"]
