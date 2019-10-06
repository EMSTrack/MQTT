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

COMMAND=$1

# Run commands
if [ "$COMMAND" = 'all' ]; then

    echo "> Starting container"

    # Trap SIGTERM
    trap 'kill ${!}; cleanup' SIGTERM

    if [ "$COMMAND" = 'all' ]; then

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