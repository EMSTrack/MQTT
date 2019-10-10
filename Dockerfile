FROM alpine:3.8

LABEL maintainer="Roger Light <roger@atchoo.org>" \
    description="Eclipse Mosquitto MQTT Broker"

ENV VERSION=1.6.7 \
    DOWNLOAD_SHA256=bcd31a8fbbd053fee328986fadd8666d3058357ded56b9782f7d4f19931d178e \
    GPG_KEYS=A0D6EEA1DCAE49A635A3B2F0779B22DFB3E717B7 \
    LWS_VERSION=2.4.2

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
        curl-dev \
        musl-dev && \
    wget https://github.com/warmcat/libwebsockets/archive/v${LWS_VERSION}.tar.gz -O /tmp/lws.tar.gz && \
    mkdir -p /build/lws && \
    tar --strip=1 -xf /tmp/lws.tar.gz -C /build/lws && \
    rm /tmp/lws.tar.gz && \
    cd /build/lws && \
    cmake . \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DLWS_IPV6=ON \
        -DLWS_WITHOUT_BUILTIN_GETIFADDRS=ON \
        -DLWS_WITHOUT_CLIENT=ON \
        -DLWS_WITHOUT_EXTENSIONS=ON \
        -DLWS_WITHOUT_TESTAPPS=ON \
        -DLWS_WITH_SHARED=OFF \
        -DLWS_WITH_ZIP_FOPS=OFF \
        -DLWS_WITH_ZLIB=OFF && \
    make -j "$(nproc)" && \
    rm -rf /root/.cmake && \
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
    rm /tmp/mosq.tar.gz && \
    make -C /build/mosq -j "$(nproc)" \
        CFLAGS="-Wall -O2 -I/build/lws/include" \
        LDFLAGS="-L/build/lws/lib" \
        WITH_ADNS=no \
        WITH_DOCS=no \
        WITH_SHARED_LIBRARIES=yes \
        WITH_SRV=no \
        WITH_STRIP=yes \
        WITH_TLS_PSK=no \
        WITH_WEBSOCKETS=yes \
        prefix=/usr \
        binary && \
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
    make; cp auth-plug.so /usr/local/lib && \
    addgroup -S -g 1883 mosquitto 2>/dev/null && \
    adduser -S -u 1883 -D -H -h /var/empty -s /sbin/nologin -G mosquitto -g mosquitto mosquitto 2>/dev/null && \
    mkdir -p /mosquitto/config /mosquitto/data /mosquitto/log && \
    install -d /usr/sbin/ && \
    install -s -m755 /build/mosq/client/mosquitto_pub /usr/bin/mosquitto_pub && \
    install -s -m755 /build/mosq/client/mosquitto_rr /usr/bin/mosquitto_rr && \
    install -s -m755 /build/mosq/client/mosquitto_sub /usr/bin/mosquitto_sub && \
    install -s -m644 /build/mosq/lib/libmosquitto.so.1 /usr/lib/libmosquitto.so.1 && \
    install -s -m755 /build/mosq/src/mosquitto /usr/sbin/mosquitto && \
    install -s -m755 /build/mosq/src/mosquitto_passwd /usr/bin/mosquitto_passwd && \
    install -m644 /build/mosq/mosquitto.conf /mosquitto/config/mosquitto.conf && \
    chown -R mosquitto:mosquitto /mosquitto && \
    apk del build-deps && \
    rm -rf /build

# configure broker
ENV HTTP_BACKEND_IP=127.0.0.1
ENV HTTP_BACKEND_PORT=8000
ENV HTTP_BACKEND_WITH_TLS=false
ENV HTTP_BACKEND_HOSTNAME=localhost
ENV HTTP_BACKEND_GETUSER_URI=/en/auth/mqtt/login/
ENV HTTP_BACKEND_SUPERUSER_URI=/en/auth/mqtt/superuser/
ENV HTTP_BACKEND_ACLCHECK_URI=/en/auth/mqtt/acl/

ENV MQTT_SUPERUSER=admin
ENV MQTT_BROKER_PORT=1883
ENV MQTT_BROKER_SSL_PORT=8883
ENV MQTT_BROKER_WEBSOCKETS_PORT=8884

ENV MQTT_BROKER_CAFILE=/etc/mosquitto/persist/certificates/my-ca.crt
ENV MQTT_BROKER_CERTFILE=/etc/mosquitto/persist/certificates/server.crt
ENV MQTT_BROKER_KEYFILE=/etc/mosquitto/persist/certificates/server.key

ENV PASS_FILE=/etc/mosquitto/persist/passwd

# /etc/mosquitto
COPY etc/mosquitto /etc/mosquitto

# daemon
COPY init.d/mosquitto /etc/init.d/mosquitto
RUN chmod +x /etc/init.d/mosquitto
RUN update-rc.d mosquitto defaults

# generate certificates
RUN mkdir -p /etc/mosquitto/persist/certificates
# COPY --chown=mosquitto:mosquitto etc/mosquitto/certificates /etc/mosquitto/certificates
WORKDIR /etc/mosquitto/persist/certificates
# https://github.com/openssl/openssl/issues/7754#issuecomment-444063355
RUN sed -i'' \
    -e 's/RANDFILE/#RANDFILE/' \
    /etc/ssl/openssl.cnf
# https://mosquitto.org/man/mosquitto-tls-7.html
# RUN openssl genrsa -des3 -passout pass:cruzroja -out server.key 2048
RUN openssl genrsa -passout pass:cruzroja -out server.key 2048
RUN openssl req -out server.csr -key server.key -passin pass:cruzroja -new \
    -subj "/C=US/ST=CA/L=San Diego/O=EMSTrack Certification/OU=Certification/CN=localhost"
# https://asciinema.org/a/201826
RUN openssl req -new -x509 -days 365 -extensions v3_ca -keyout my-ca.key -out my-ca.crt \
    -passout pass:cruzroja -passin pass:cruzroja \
    -subj "/C=US/ST=CA/L=San Diego/O=EMSTrack MQTT/OU=MQTT/CN=localhost"
RUN openssl x509 -req -in server.csr -CA my-ca.crt -CAkey my-ca.key -CAcreateserial \
    -passin pass:cruzroja -out server.crt -days 180

# make persist writable
RUN chown -R mosquitto:mosquitto /etc/mosquitto/persist

# make persist the current directory
WORKDIR /etc/mosquitto/persist

# entrypoint
COPY docker-entrypoint.sh /usr/local/bin/

# Entrypoint script
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Add VOLUME to allow access to certificates, logs, and passwd
VOLUME ["/etc/mosquitto/persist"]

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["all"]
