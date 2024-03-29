FROM golang:1.19-buster AS builder

ENV SRC_PATH    /build
ENV GO111MODULE on
ENV GOPROXY     https://proxy.golang.org

# Install build deps for lily and lily-archiver
RUN apt-get update -y && \
    apt-get install git make ca-certificates jq hwloc libhwloc-dev mesa-opencl-icd ocl-icd-opencl-dev -y && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . "$HOME/.cargo/env"

WORKDIR $SRC_PATH

RUN git clone --depth 1 https://github.com/filecoin-project/lily.git && \
    cd lily && CGO_ENABLED=1 make clean all

FROM buildpack-deps:buster-curl

# Install aria2 and zstd
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends aria2 zstd jq

ENV SRC_PATH /build

COPY --from=builder $SRC_PATH/lily/lily /usr/local/bin/lily
COPY --from=builder /usr/lib/x86_64-linux-gnu/libOpenCL.so* /lib/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libhwloc.so* /lib/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libnuma.so* /lib/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libltdl.so* /lib/

# Add required files
COPY config.toml scripts gce_batch_job.json /lily/

# Create data folder
WORKDIR /tmp/data

ENTRYPOINT ["/bin/bash"]
