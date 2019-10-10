#!/bin/ash

sigint_handler()
{
  kill $(jobs -p)
  exit
}

trap sigint_handler SIGINT

set -e
while true; do
  $@ &
  PID=$!
  inotifywait -e modify -e move -e create -e delete -e attrib /mosquitto/config/reload
  kill $PID
done
