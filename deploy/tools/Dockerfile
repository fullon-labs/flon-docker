FROM ubuntu:22.04

ARG TOOLS_VERSION=0.9.0
ARG TOOLS_SHA256=fcd43e29106d4f381a3af0fd021b26a747012e8c3d16a51d8b82bbe50b66e9bf

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && curl -fsSL "https://github.com/fullon-labs/flon-core/releases/download/v${TOOLS_VERSION}/flon-core-tools_${TOOLS_VERSION}-ubuntu22.04_amd64.deb" -o /tmp/flon-core-tools.deb \
    && echo "${TOOLS_SHA256}  /tmp/flon-core-tools.deb" | sha256sum -c - \
    && apt-get install -y --no-install-recommends /tmp/flon-core-tools.deb \
    && rm -f /tmp/flon-core-tools.deb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
CMD ["bash"]
