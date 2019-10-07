#!/bin/bash

pid=0

# Cleanup
cleanup() {

    echo "Container stopped, cleaning up..."

    echo "Exiting..."

    if [ $pid -ne 0 ]; then
	kill -SIGTERM "$pid"
	wait "$pid"
    fi
    exit 143; # 128 + 15 -- SIGTERM

}

# Escape path for use with sed
function sedPath {
    local path=$((echo $1|sed -r 's/([\$\.\*\/\[\\^])/\\\1/g'|sed 's/[]]/\[]]/g')>&1)
    echo "$path"
}

COMMAND=$1

# Run commands
if [ "$COMMAND" = 'all' ]; then

    echo "> Starting container"

    # Trap SIGTERM
    trap 'kill ${!}; cleanup' SIGTERM

    if [ "$COMMAND" = 'all' ]; then

    echo "$(sedPath $HTTP_BACKEND_GETUSER_URI)"

	echo "> Configuring MQTT service"
	sed -i'' \
        -e 's/\[http-backend-ip\]/'"$HTTP_BACKEND_IP"'/g' \
        -e 's/\[http-backend-port\]/'"$HTTP_BACKEND_PORT"'/g' \
        -e 's/\[http-backend-with_tls\]/'"$HTTP_BACKEND_WITH_TLS"'/g' \
        -e 's/\[http-backend-hostname\]/'"$HTTP_BACKEND_HOSTNAME"'/g' \
        -e 's/\[http-backend-getuser-uri\]/'"$(sedPath $HTTP_BACKEND_GETUSER_URI)"'/g' \
        -e 's/\[http-backend-superuser-uri\]/'"$(sedPath $HTTP_BACKEND_SUPERUSER_URI)"'/g' \
        -e 's/\[http-backend-aclcheck-uri\]/'"$(sedPath $HTTP_BACKEND_ACLCHECK_URI)"'/g' \
        -e 's/\[mqtt-superuser\]/'"$MQTT_SUPERUSER"'/g' \
        -e 's/\[mqtt-broker-port\]/'"$MQTT_BROKER_PORT"'/g' \
        -e 's/\[mqtt-broker-ssl-port\]/'"$MQTT_BROKER_SSL_PORT"'/g' \
        -e 's/\[mqtt-broker-websockets-port\]/'"$MQTT_BROKER_WEBSOCKETS_PORT"'/g' \
        -e 's/\[mqtt-broker-cafile\]/'"$(sedPath $MQTT_BROKER_CAFILE)"'/g' \
        -e 's/\[mqtt-broker-certfile\]/'"$(sedPath $MQTT_BROKER_CERTFILE)"'/g' \
        -e 's/\[mqtt-broker-keyfile\]/'"$(sedPath $MQTT_BROKER_KEYFILE)"'/g' \
        /etc/mosquitto/conf.d/default.conf

	echo "> Starting MQTT service"
	service mosquitto start

	echo "> All services up"

    fi

    pid="$!"

    # Wait forever
    while true
    do
	tail -f /dev/null & wait ${!}
    done

    # Call cleanup
    cleanup

else

    echo "> No services started"
    echo "> Running '$@'"

    exec "$@"

fi