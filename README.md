# MQTT

This builds a container based on the [eclipse-mosquitto:1.6.7](https://hub.docker.com/_/eclipse-mosquitto) image
and our local version of the [Mosquitto Authentication Plugin](https://github.com/EMSTrack/mosquitto-auth-plug).

Our fork of the MAP has minimal updates to compile with the latest version of mosquitto.

http and file authentication are the only ones enabled by default.
