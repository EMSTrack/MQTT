#!/bin/ash

sigint_handler()
{
  kill $(jobs -p)
  exit
}

trap sigint_handler SIGINT

set -e
touch /mosquitto/config/reload
while true; do
  $@ > /mosquitto/log/mosquitto.log 2>&1 &
  PID=$!
  inotifywait -e modify -e move -e create -e delete -e attrib /mosquitto/config/reload
  kill $PID
done
