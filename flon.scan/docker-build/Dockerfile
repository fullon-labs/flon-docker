# Stage 1: Build Environment
FROM ubuntu:22.04 as base

SHELL ["/bin/bash", "-c"]

# Build Arguments
ARG BRANCH
ARG REPO
ARG CMAKE_BUILD_TYPE=Release

# Set Non-Interactive Frontend
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse" >> /etc/apt/sources.list 
RUN echo /etc/apt/sources.list 

# Install Build Dependencies
RUN apt-get update && \
    apt-get install -y \
        autoconf2.13 \
        build-essential \
        cmake \
        curl \
        git \
        libboost-all-dev \
        libcurl4-openssl-dev \
        libgmp-dev \
        libpq-dev \
        libpqxx-dev \
        libssl-dev \
        ninja-build \
        openssl \
        python3-pkgconfig && \
    apt-get clean && \
    rm -rf /var/cache/apt/lists/*

# Clone Repository
RUN git clone --recursive "$REPO" -b "$BRANCH" /root/history-tools

# Build Project
WORKDIR /root/history-tools/build
RUN cmake -GNinja -DCMAKE_BUILD_TYPE=$CMAKE_BUILD_TYPE -DPostgreSQL_TYPE_INCLUDE_DIR=/usr/include/postgresql .. && \
    ninja

# Stage 2: Runtime Environment
FROM ubuntu:22.04

# Set Timezone
RUN echo "Asia/Shanghai" > /etc/timezone && \
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    RUN echo "deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse" >> /etc/apt/sources.list 
RUN echo /etc/apt/sources.list 

# Install Runtime Dependencies
RUN apt-get update && \
    apt-get install -y \
        netcat \
        openssl \
        postgresql-client \
        gcc-10 g++-10 && \
    apt-get clean && \
    rm -rf /var/cache/apt/lists/*

# Copy Executable from Build Stage
COPY --from=base /root/history-tools/build/fill-pg /usr/local/bin/fill-pg

# Set Default Command (if needed)
CMD ["fill-pg"]