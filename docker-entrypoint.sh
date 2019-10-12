#!/bin/ash

sigint_handler()
{
  kill $(jobs -p)
  exit
}

trap sigint_handler SIGINT

set -e

touch /mosquitto/data/reload
while true; do
    echo "Starting mosquitto..."
    $@ > /mosquitto/log/mosquitto.log 2>&1 &
    PID=$!
    echo "Mosquitto started"
    inotifywait -e modify -e move -e create -e delete -e attrib /mosquitto/data/reload
    echo "Stopping mosquitto..."
    kill -s SIGINT $PID
    echo "Mosquitto stopped"
    sleep 2
done
