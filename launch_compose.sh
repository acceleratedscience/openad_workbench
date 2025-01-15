#!/bin/sh

podman compose up -d

sleep 5

echo "Cataloging services for OpenAD Materials Demonstration Environment..."

podman exec -it materials_wb openad "catalog model service from remote 'openad_properties:8080' as prop "
echo "\n"
podman exec -it materials_wb openad "catalog model service from remote 'openad_generation:8080' as gen "


echo "it make a few minutes until all services are available\n\n"
echo "----------------------------------------------------------"
echo "your notebook can be located at http://127.0.0.1:8888"


echo "Waiting for Properties Service to be started"
while [ "`curl -s 127.0.0.1:8080/health `" != "UP" ]; do     sleep 2; done

echo "Waiting for generation Service to be started"
while [ "`curl -s 127.0.0.1:8090/health`" != "UP" ]; do     sleep 2; done
