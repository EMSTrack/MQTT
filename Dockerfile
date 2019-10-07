# Using ubuntu as a base image
FROM ubuntu:18.04

# Getting rid of debconf messages
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update -y
RUN apt-get install -y apt-utils git
RUN apt-get install -y make gcc g++

# Install opensll, curl
RUN apt-get install -y curl openssl libcurl4-openssl-dev

# Install libwebsockets
RUN apt-get install -y libwebsockets-dev

# Download source code for mosquitto
WORKDIR /src
RUN git clone https://github.com/eclipse/mosquitto
WORKDIR /src/mosquitto
# RUN git checkout 8025f5a29b78551e1d5e9ea13ae9dacabb6830da

# Configure and build mosquitto
WORKDIR /src/mosquitto
RUN cp config.mk config.mk.in
RUN sed -e 's/WITH_SRV:=yes/WITH_SRV:=no/' \
        -e 's/WITH_WEBSOCKETS:=no/WITH_WEBSOCKETS:=yes/' \
	-e 's/WITH_DOCS:=yes/WITH_DOCS:=no/' \
	config.mk.in > config.mk

RUN make binary install

# add mosquitto user
RUN useradd -M mosquitto
RUN usermod -L mosquitto

# /etc/mosquitto
COPY etc/mosquitto /etc/mosquitto

# daemon
COPY init.d/mosquitto /etc/init.d/mosquitto
RUN chmod +x /etc/init.d/mosquitto
RUN update-rc.d mosquitto defaults

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

ENV MQTT_BROKER_CAFILE=/etc/mosquitto/persist/certificates/ca.crt
ENV MQTT_BROKER_CERTFILE=/etc/mosquitto/persist/certificates/srv.crt
ENV MQTT_BROKER_KEYFILE=/etc/mosquitto/persist/certificates/srv.key

# create passwd
RUN mkdir -p /etc/mosquitto/persist
WORKDIR /etc/mosquitto/persist
RUN touch passwd

# make persist writable
RUN chown -R mosquitto:mosquitto /etc/mosquitto/persist

# entrypoint
COPY docker-entrypoint.sh /usr/local/bin/

# Entrypoint script
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Add VOLUME to allow access to certificates, logs, and passwd
VOLUME ["/etc/mosquitto/persist"]

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["all"]
