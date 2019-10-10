# Using ubuntu as a base image
FROM eclipse-mosquitto:1.6

# make available run pip install psycopg2
RUN apk update && \
    apk add git make gcc libc-dev

# Download source code for mosquitto-auth-plug
WORKDIR /src
#RUN git clone https://github.com/jpmens/mosquitto-auth-plug
RUN git clone https://github.com/EMSTrack/mosquitto-auth-plug
WORKDIR /src/mosquitto-auth-plug
# RUN git checkout 481331fa57760bfe5934164c69784df70692bd65

# Configure and build mosquitto-auth-plug
WORKDIR /src/mosquitto-auth-plug
RUN sed -e 's/BACKEND_MYSQL ?= yes/BACKEND_MYSQL ?= no/' \
        -e 's/BACKEND_FILES ?= no/BACKEND_FILES ?= yes/' \
        -e 's/BACKEND_HTTP ?= no/BACKEND_HTTP ?= yes/' \
        -e 's,MOSQUITTO_SRC =,MOSQUITTO_SRC =/src/mosquitto,' \
        -e 's,OPENSSLDIR = /usr,OPENSSLDIR = /usr/bin,' \
        config.mk.in > config.mk
RUN make; cp auth-plug.so /usr/local/lib

# Run ldconfig
RUN ldconfig

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
