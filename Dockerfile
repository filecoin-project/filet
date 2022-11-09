FROM filecoin/lily:v0.12.0

# Install aria2 and gcloud
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && curl https://packages.cloud.google.com/ \
    && apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends aria2 zstd

# Add required files
COPY config.toml scripts gce_batch_job.json /lily/

# Create data folder
WORKDIR /tmp/data

# Run script
ENTRYPOINT [ "/bin/bash" ]
