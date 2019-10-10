FROM eclipse-mosquitto:1.6.7

#ENV VERSION=1.6.7 \
#    DOWNLOAD_SHA256=bcd31a8fbbd053fee328986fadd8666d3058357ded56b9782f7d4f19931d178e \
#    GPG_KEYS=A0D6EEA1DCAE49A635A3B2F0779B22DFB3E717B7 \
#    LWS_VERSION=2.4.2

# setup environment and copy current source version of mosquitto
RUN set -x && \
    apk --no-cache add --virtual build-deps \
        build-base \
        cmake \
        gnupg \
        libressl-dev \
        util-linux-dev \
        make \
        gcc \
        libc-dev \
        curl-dev && \
    wget https://mosquitto.org/files/source/mosquitto-${VERSION}.tar.gz -O /tmp/mosq.tar.gz && \
    echo "$DOWNLOAD_SHA256  /tmp/mosq.tar.gz" | sha256sum -c - && \
    wget https://mosquitto.org/files/source/mosquitto-${VERSION}.tar.gz.asc -O /tmp/mosq.tar.gz.asc && \
    export GNUPGHOME="$(mktemp -d)" && \
    found=''; \
    for server in \
        ha.pool.sks-keyservers.net \
        hkp://keyserver.ubuntu.com:80 \
        hkp://p80.pool.sks-keyservers.net:80 \
        pgp.mit.edu \
    ; do \
        echo "Fetching GPG key $GPG_KEYS from $server"; \
        gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
    gpg --batch --verify /tmp/mosq.tar.gz.asc /tmp/mosq.tar.gz && \
    gpgconf --kill all && \
    rm -rf "$GNUPGHOME" /tmp/mosq.tar.gz.asc && \
    mkdir -p /build/mosq && \
    tar --strip=1 -xf /tmp/mosq.tar.gz -C /build/mosq && \
    rm /tmp/mosq.tar.gz

RUN set -x && \
    cp /usr/lib/libmosquitto.so.1 /usr/lib/libmosquitto.so
    cd /build && \
    wget https://github.com/EMSTrack/mosquitto-auth-plug/archive/master.tar.gz -O /tmp/map.tar.gz && \
    mkdir -p /build/map && \
    tar --strip=1 -xf /tmp/map.tar.gz -C /build/map && \
    rm /tmp/map.tar.gz && \
    cd /build/map && \
    sed -e 's/BACKEND_MYSQL ?= yes/BACKEND_MYSQL ?= no/' \
        -e 's/BACKEND_FILES ?= no/BACKEND_FILES ?= yes/' \
        -e 's/BACKEND_HTTP ?= no/BACKEND_HTTP ?= yes/' \
        -e 's,MOSQUITTO_SRC =,MOSQUITTO_SRC =/build/mosq,' \
        -e 's,OPENSSLDIR = /usr,OPENSSLDIR = /usr/bin,' \
        config.mk.in > config.mk && \
    make; cp auth-plug.so /usr/lib && \
    apk del build-deps && \
    rm -rf /build
