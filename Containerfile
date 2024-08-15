FROM quay.io/opendatahub-contrib/workbench-images:base-c9s-py311_2023c_latest

LABEL name="workbench-images:jupyter-minimal-c9s-py311_2023c_20240703" \
    summary="jupyter-minimal workbench image with Python py311 based on c9s" \
    description="jupyter-minimal workbench image with Python py311 based on c9s" \
    io.k8s.description="jupyter-minimal workbench image  with Python py311 based on c9s for ODH or RHODS" \
    io.k8s.display-name="jupyter-minimal workbench image  with Python py311 based on c9s" \
    authoritative-source-url="https://github.com/opendatahub-contrib/workbench-images" \
    io.openshift.build.commit.ref="2023c" \
    io.openshift.build.source-location="https://github.com/opendatahub-contrib/workbench-images" \
    io.openshift.build.image="https://quay.io/opendatahub-contrib/workbench-images:jupyter-minimal-c9s-py311_2023c_20240703"

##########################
# Deploy Python packages #
##########################

USER 1001

WORKDIR /opt/app-root/bin/

# Copy packages list
COPY --chown=1001:0 requirements.txt ./

# Install packages and cleanup
# (all commands are chained to minimize layer size)
RUN echo "Installing softwares and packages" && \
    # Install Python packages \
    pip install --no-cache-dir -r requirements.txt && \
    # Fix permissions to support pip in Openshift environments \
    chmod -R g+w /opt/app-root/lib/python3.11/site-packages && \
    fix-permissions /opt/app-root -P  
   

WORKDIR /opt/app-root/src/

##########################

###########################
# Deploy OS Packages      #
###########################

USER 0

WORKDIR /opt/app-root/bin/

COPY --chown=1001:0 os-ide/os-packages.txt ./os-ide/os-packages.txt

RUN yum install -y $(cat os-ide/os-packages.txt) && \
    rm -f os-ide/os-packages.txt && \
    yum -y clean all --enablerepo='*' && \
    rm -rf /var/cache/dnf && \
    find /var/log -type f -name "*.log" -exec rm -f {} \;




###########################

##############################
# Deploy Jupyterlab packages #
##############################

USER 1001

WORKDIR /opt/app-root/bin

# Copy packages list
COPY --chown=1001:0 requirements-jupyter.txt ./
COPY --chown=1001:0 utils utils/

# Streamlit extension installation
COPY --chown=1001:0 streamlit-launcher.sh ./
COPY --chown=1001:0 streamlit-menu/dist/jupyterlab_streamlit_menu-0.1.0-py3-none-any.whl ./

# Copy Elyra setup to utils so that it's sourced at startup
COPY --chown=1001:0 setup-elyra.sh ./utils/

# copy demo Menus
COPY --chown=1001:0 Start.ipynb ./
COPY --chown=1001:0 start_menu.ipynb ./

# Install packages and cleanup
# (all commands are chained to minimize layer size)
RUN echo "Installing softwares and packages" && \
    # Install Python packages \
    npm install @ibm/plex && \
    pip install --no-cache-dir -r requirements-jupyter.txt && \
    pip install --no-cache-dir ./jupyterlab_streamlit_menu-0.1.0-py3-none-any.whl && \
    rm -f ./jupyterlab_streamlit_menu-0.1.0-py3-none-any.whl && \
    pip install "jupyterlab_rise<0.40.0" && \
    # requred as it crashes on openad install due to higher version causing problem with 3.10.7 rust code
    pip install --no-cache-dir openad && \
    ipython profile create && \
    init_magic && \ 
    # setup path for runtime configuration \
    mkdir /opt/app-root/runtimes && \
    # switch to Data Science Pipeline \
    cp utils/pipeline-flow.svg /opt/app-root/lib/python3.11/site-packages/elyra/static/icons/kubeflow.svg && \
    sed -i "s/Kubeflow Pipelines/Data Science/g" /opt/app-root/lib/python3.11/site-packages/elyra/pipeline/runtime_type.py && \
    sed -i "s/Kubeflow Pipelines/Data Science Pipelines/g" /opt/app-root/lib/python3.11/site-packages/elyra/metadata/schemas/kfp.json && \
    sed -i "s/kubeflow-service/data-science-pipeline-service/g" /opt/app-root/lib/python3.11/site-packages/elyra/metadata/schemas/kfp.json && \
    sed -i "s/\"default\": \"Argo\",/\"default\": \"Tekton\",/g" /opt/app-root/lib/python3.11/site-packages/elyra/metadata/schemas/kfp.json && \
    # Workaround for passing ssl_sa_cert and to ensure that Elyra redirects to a correct pipeline run URL \
    patch /opt/app-root/lib/python3.11/site-packages/elyra/pipeline/kfp/kfp_authentication.py -i utils/kfp_authentication.patch && \
    patch /opt/app-root/lib/python3.11/site-packages/elyra/pipeline/kfp/processor_kfp.py -i utils/processor_kfp.patch && \
    # switch to Data Science Pipeline in component catalog \
    DIR_COMPONENT="/opt/app-root/lib/python3.11/site-packages/elyra/metadata/schemas/local-directory-catalog.json" && \
    FILE_COMPONENT="/opt/app-root/lib/python3.11/site-packages/elyra/metadata/schemas/local-file-catalog.json" && \
    URL_COMPONENT="/opt/app-root/lib/python3.11/site-packages/elyra/metadata/schemas/url-catalog.json" && \
    tmp=$(mktemp) && \
    jq '.properties.metadata.properties.runtime_type = input' $DIR_COMPONENT utils/component_runtime.json > "$tmp" && mv "$tmp" $DIR_COMPONENT && \
    jq '.properties.metadata.properties.runtime_type = input' $FILE_COMPONENT utils/component_runtime.json > "$tmp" && mv "$tmp" $FILE_COMPONENT && \
    jq '.properties.metadata.properties.runtime_type = input' $URL_COMPONENT utils/component_runtime.json > "$tmp" && mv "$tmp" $URL_COMPONENT && \
    sed -i "s/metadata.metadata.runtime_type/\"DATA_SCIENCE_PIPELINES\"/g" /opt/app-root/share/jupyter/labextensions/@elyra/pipeline-editor-extension/static/lib_index_js.*.js && \
    # Remove Elyra logo from JupyterLab because this is not a pure Elyra image \
    sed -i "s/widget\.id === \x27jp-MainLogo\x27/widget\.id === \x27jp-MainLogo\x27 \&\& false/" /opt/app-root/share/jupyter/labextensions/@elyra/theme-extension/static/lib_index_js.*.js && \
    # Replace Notebook's launcher, "(ipykernel)" with Python's version 3.x.y \
    sed -i -e "s/Python.*/$(python --version | cut -d '.' -f-2)\",/" /opt/app-root/share/jupyter/kernels/python3/kernel.json && \
    # Remove default Elyra runtime-images \
    rm /opt/app-root/share/jupyter/metadata/runtime-images/*.json && \
    # Fix permissions to support pip in Openshift environments \
    chmod -R g+w /opt/app-root/lib/python3.11/site-packages && \
    fix-permissions /opt/app-root -P

# Copy Elyra runtime-images definitions and set the version
COPY --chown=1001:0 runtime-images/ /opt/app-root/share/jupyter/metadata/runtime-images/
COPY --chown=1001:0 custom.css $/opt/app-root/share/jupyter/custom/custom.css 
COPY --chown=1001:0 custom.css $/opt/app-root/share/jupyter/custom.css
COPY --chown=1001:0 jupyter_lab_config.py /opt/app-root/src/.jupyter/jupyter_lab_config.py

RUN sed -i "s/RELEASE/2023c/" /opt/app-root/share/jupyter/metadata/runtime-images/*.json  

COPY --chown=1001:0 process_creds.py ./
COPY --chown=1001:0 etc/ /opt/app-root/etc/jupyter/
COPY --chown=1001:0 etc/  /opt/app-root/src/.jupyter/
COPY --chown=1001:0 start-notebook.sh ./
# Copy notebook launcher and utils

WORKDIR /opt/app-root/src

ENTRYPOINT ["start-notebook.sh"]


