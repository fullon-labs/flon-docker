ARG FLON_VERSION=v0.9.0
FROM ghcr.io/fullon-labs/floncore/floncdt:${FLON_VERSION}

ARG TOOLS_VERSION=0.9.0
ARG TOOLS_SHA256=fcd43e29106d4f381a3af0fd021b26a747012e8c3d16a51d8b82bbe50b66e9bf
RUN curl -fsSL "https://github.com/fullon-labs/flon-core/releases/download/v${TOOLS_VERSION}/flon-core-tools_${TOOLS_VERSION}-ubuntu22.04_amd64.deb" -o /tmp/flon-tools.deb \
    && echo "${TOOLS_SHA256}  /tmp/flon-tools.deb" | sha256sum -c - \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/flon-tools.deb \
    && rm -f /tmp/flon-tools.deb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
CMD ["sleep", "infinity"]
