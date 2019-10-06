# Using ubuntu as a base image
FROM ubuntu:18.04

# Getting rid of debconf messages
ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update -y
RUN apt-get install -y apt-utils git

# Install opensll
RUN apt-get install -y openssl

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
COPY etc/mosquitto/mosquitto.conf /etc/mosquitto/mosquitto.conf
COPY etc/mosquitto/conf.d /etc/mosquitto/conf.d

# daemon
COPY init.d/mosquitto /etc/init.d/mosquitto
RUN chmod +x /etc/init.d/mosquitto
RUN update-rc.d mosquitto defaults

# /var/log/mosquitto
RUN mkdir /var/log/mosquitto
RUN chown mosquitto:mosquitto /var/log/mosquitto

# /var/lib/mosquitto
RUN mkdir /var/lib/mosquitto
RUN chown mosquitto:mosquitto /var/lib/mosquitto

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

# configure broker
ARG MQTT_BROKER_HTTP_IP=127.0.0.1
ARG MQTT_BROKER_HTTP_PORT=8000
ARG MQTT_BROKER_HTTP_WITH_TLS=false
ARG MQTT_BROKER_HTTP_HOSTNAME=localhost

ARG MQTT_USERNAME=admin
ARG MQTT_BROKER_PORT=1883
ARG MQTT_BROKER_SSL_PORT=8883
ARG MQTT_BROKER_WEBSOCKETS_PORT=8884

RUN sed -i'' \
    -e 's/\[ip\]/'"$MQTT_BROKER_HTTP_IP"'/g' \
    -e 's/\[port\]/'"$MQTT_BROKER_HTTP_PORT"'/g' \
    -e 's/\[with_tls\]/'"$MQTT_BROKER_HTTP_WITH_TLS"'/g' \
    -e 's/\[hostname\]/'"$MQTT_BROKER_HTTP_HOSTNAME"'/g' \
    -e 's/\[mqtt-username\]/'"$MQTT_USERNAME"'/g' \
    -e 's/\[mqtt-broker-port\]/'"$MQTT_BROKER_PORT"'/g' \
    -e 's/\[mqtt-broker-ssl-port\]/'"$MQTT_BROKER_SSL_PORT"'/g' \
    -e 's/\[mqtt-broker-websockets-port\]/'"$MQTT_BROKER_WEBSOCKETS_PORT"'/g' \
    /etc/mosquitto/conf.d/default.conf

# entrypoint
COPY docker-entrypoint.sh /usr/local/bin/

# Entrypoint script
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["all"]
