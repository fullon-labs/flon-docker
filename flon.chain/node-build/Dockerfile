# Stage 1: Build environment
FROM ubuntu:22.04 AS builder
SHELL ["/bin/bash", "-c"]

# Build arguments
ARG BRANCH
ARG REPO
ARG MODE
ARG LOCAL_PATH
ARG FULLON_VERSION
ARG CMAKE_BUILD_TYPE=Release

RUN echo "deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse" >> /etc/apt/sources.list 

    # Install dependencies and clean cache
RUN apt-get update && apt-get install -y \
    git \
    sudo \
    build-essential \
    cmake \
    libcurl4-openssl-dev \
    libgmp-dev \
    llvm-11-dev \
    python3-numpy \
    file \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /fullon

# Copy local code or clone remote repository based on mode
RUN if [ "$MODE" = "local" ]; then \
        echo "Building in local data mode"; \
        cp -r ${LOCAL_PATH} /fullon; \
    else \
        echo "Building in git clone mode"; \
        git clone --recursive "$REPO" -b "$BRANCH" .; \
    fi

RUN cat ./CMakeLists.txt
# Build the project
RUN mkdir -p build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -DCMAKE_PREFIX_PATH=/usr/lib/llvm-11 .. && \
    make -j "$(nproc)" package

# Extract the generated .deb file
RUN cp "$(ls -t /fullon/build/flon-core_*-ubuntu22.04_amd64.deb | head -n 1)" /fullon.install.deb

# Stage 2: Runtime environment
FROM phusion/baseimage:jammy-1.0.4

# Copy .deb file from the build stage
COPY --from=builder /fullon.install.deb /fullon.install.deb
RUN echo "deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse" >> /etc/apt/sources.list 

# Install runtime dependencies and Fullon
RUN apt-get update --fix-missing && apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libusb-1.0-0 \
    libcurl3-gnutls \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Fullon
RUN apt-get update && apt-get install -y /fullon.install.deb && \
    rm -rf /fullon.install.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /opt/fullon

# Default command (can be customized as needed)
CMD ["bash"]
