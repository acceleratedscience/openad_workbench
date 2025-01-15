#!/bin/sh

if nvidia-smi; then
    GPUS="--gpus all"
else
    GPUS=" "
fi

if [ "$(uname -s)" = "Darwin" ]; then
    NETWORK=" "
else
    NETWORK = "--network=host"
fi

if echo "$*" | grep -iq -- "\bcache\b"; then
    if [[ ! -e $HOME/MATERIALS/.openad ]]; then
        mkdir -p $HOME/MATERIALS/.openad
    fi

     if [[ ! -e $HOME/.gt4sd ]]; then
        mkdir $HOME/.gt4sd
    fi

    if [[ ! -e $HOME/.cache ]]; then
        mkdir $HOME/.cache
    fi

    if [[ ! -e $HOME/.oracle ]]; then
        mkdir $HOME/.oracle
    fi


        CACHE=' -v $HOME/.gt4sd:/root/.gt4sd:Z -v $HOME/.oracle:/root/.oracle:Z -v $HOME/.cache:/root/.cache:Z '
        WB_CACHE=' -v $HOME/.openad:/opt/app-root/src/.openad:Z  '
    else
        CACHE=" "
        WB_CACHE=" "
fi


#set -e

# Check if the container is already running
if podman ps --all  | grep  -i "\bproperties\b" ; then
    # If the container is running, stop it and start a new one
    echo "Stopping current OpenAD Properties container..."
    
    podman rm -f properties
    sleep 5
    
fi 
eval "podman run   --name properties -d  $GPUS $CACHE -p 8080:8080 quay.io/ibmdpdev/openad-properties:latest"
echo "Starting new OpenAD Properties container on port 8080...\n"



if podman ps --all  | grep  -i "\bgeneration\b"; then
    # If the container is running, stop it and start a new one
    echo "Stopping current OpenAD Generation container..."
   
    podman rm -f generation
    sleep 5
    
fi 

eval "podman run --name generation -d  $GPUS $CACHE -p 8090:8080 quay.io/ibmdpdev/openad-generation:latest"
echo "Starting new OpenAD Generation container on port 8090...\n"

if podman ps --all  | grep  -i "\bmaterials_wb\b"; then
    # If the container is running, stop it and start a new one
    echo "Stopping current OpenAD Properties container..."
    
    podman rm -f materials_wb
    sleep 5
    
fi 

eval """ podman run --name materials_wb -d -e NOTEBOOK_ARGS="--ServerApp.token=''"  $WB_CACHE -p 8888:8888  quay.io/ibmdpdev/openad_workbench:latest -e NOTEBOOK_VERSION="materials" """
echo "Starting new OpenAD Materials Workbench container on port 8888...\n"

sleep 5

echo "Cataloging services for OpenAD Materials Demonstration Environment..."
if  [ "$(uname -s)" = "Darwin" ]; then
    echo "Using podman on Mac OS requires the cataloging using podman intnernal address\n"
    ip=$(podman inspect properties -f '{{ .NetworkSettings.IPAddress }}')
    podman exec -it materials_wb openad "catalog model service from remote '${ip}:8080' as prop "
    ip=$(podman inspect generation -f '{{ .NetworkSettings.IPAddress }}')
    podman exec -it materials_wb openad "catalog model service from remote '${ip}:8080' as gen "
else
    podman exec -it materials_wb openad "catalog model service from remote '127.0.0.1:8080' as prop "
    echo "\n"
    podman exec -it materials_wb openad "catalog model service from remote '127.0.0.1:8090' as gen "
fi

echo "it make a few minutes until all services are available\n\n"
echo "----------------------------------------------------------"
echo "your notebook can be located at http://127.0.0.1:8888"
