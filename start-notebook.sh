#!/usr/bin/env bash

# Load bash libraries
SCRIPT_DIR=/opt/app-root/bin
source ${SCRIPT_DIR}/utils/process.sh

if [ -f "${SCRIPT_DIR}/utils/setup-elyra.sh" ]; then
  source ${SCRIPT_DIR}/utils/setup-elyra.sh
fi

# Initialize notebooks arguments variable
NOTEBOOK_PROGRAM_ARGS=""

# Set default ServerApp.port value if NOTEBOOK_PORT variable is defined
if [ -n "${NOTEBOOK_PORT}" ]; then
    NOTEBOOK_PROGRAM_ARGS+="--ServerApp.port=${NOTEBOOK_PORT} "
fi

# Set default ServerApp.base_url value if NOTEBOOK_BASE_URL variable is defined
if [ -n "${NOTEBOOK_BASE_URL}" ]; then
    NOTEBOOK_PROGRAM_ARGS+="--ServerApp.base_url=${NOTEBOOK_BASE_URL} "
fi

if [ -n "${NOTEBOOK_BASE_URL}" ]; then
    NOTEBOOK_PROGRAM_ARGS+=" --LabApp.default_url=${NOTEBOOK_BASE_URL}/lab/tree/start_menu.ipynb "
else
    NOTEBOOK_PROGRAM_ARGS+=" --LabApp.default_url=/lab/workspaces/auto-s/tree/start_menu.ipynb "
fi

# Set default ServerApp.root_dir value if NOTEBOOK_ROOT_DIR variable is defined
if [ -n "${NOTEBOOK_ROOT_DIR}" ]; then
    NOTEBOOK_PROGRAM_ARGS+="--ServerApp.root_dir=${NOTEBOOK_ROOT_DIR} "
else
    NOTEBOOK_PROGRAM_ARGS+="--ServerApp.root_dir=${HOME} "
fi

# Add additional arguments if NOTEBOOK_ARGS variable is defined
if [ -n "${NOTEBOOK_ARGS}" ]; then
    NOTEBOOK_PROGRAM_ARGS+=${NOTEBOOK_ARGS}
elif [ -n "${OPENAD_AUTH}" ]; then
    NOTEBOOK_PROGRAM_ARGS+=" --ServerApp.token=${OPENAD_AUTH} "

fi
NOTEBOOK_PROGRAM_ARGS+=" --ServerApp.disable_check_xsrf=True "
# Add .bashrc for custom promt if not present
if [ ! -f "/opt/app-root/src/.bashrc" ]; then
  echo 'PS1="\[\033[34;1m\][\$(pwd)]\[\033[0m\]\n\[\033[1;0m\]$ \[\033[0m\]"' > /opt/app-root/src/.bashrc
fi

# Start the JupyterLab notebook
! [ -d "$HOME/openad_notebooks" ] && init_examples && ipython profile create && init_magic
! [ -e "$HOME/Start.ipynb" ] && cp /opt/app-root/bin/Start.ipynb ./
! [ -e "$HOME/start_menu.ipynb" ] && cp /opt/app-root/bin/start_menu.ipynb ./

! [ -d "/opt/app-root/src/.jupyter" ] && mkdir /opt/app-root/src/.jupyter
cp  /opt/app-root/etc/jupyter/jupyter_lab_config.py /opt/app-root/src/.jupyter/


jupyter trust $HOME/openad_notebooks/*.ipynb && \
jupyter trust $HOME/*.ipynb 
#initialise openad files
openad "?"

python /opt/app-root/bin/process_creds.py

start_process jupyter lab ${NOTEBOOK_PROGRAM_ARGS} 
#start_process jupyter lab ${NOTEBOOK_PROGRAM_ARGS} \
#    --ServerApp.ip=0.0.0.0 \
#    --ServerApp.allow_origin="*" \
#    --ServerApp.open_browser=False  \
#    --ServerApp.token='' --LabApp.default_url='/lab/workspaces/auto-s/tree/start_menu.ipynb'
