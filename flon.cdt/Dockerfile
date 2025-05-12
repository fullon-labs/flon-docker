# Stage 1: Build flon.cdt
FROM ubuntu:22.04 as builder


RUN echo "deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse" >> /etc/apt/sources.list 
RUN echo /etc/apt/sources.list 

# Install dependencies and build tools
RUN apt-get update && apt-get install -y build-essential clang clang-tidy cmake git libxml2-dev \
            opam ocaml-interp python3 python3-pip time                  
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Python 3.7.4 and development files
RUN python3 -m pip install pygments

ENV SRC_DIR=/flon.cdt
RUN mkdir -p ${SRC_DIR}
WORKDIR ${SRC_DIR}

# Clone and build flon.cdt
RUN git clone --recursive https://github.com/fullon-labs/flon.cdt.git ${SRC_DIR} && \
    export CCACHE_DISABLE=1 && \
    mkdir build && cd build && \
    cmake -DPython_ROOT_DIR=/usr/local .. && \
    make -j$(nproc)

# RUN cd build/packages && bash ./generate_package.sh "deb" \
#     && mv "$( ls -t flon.cdt*.deb | head -1 )" /flon.cdt.deb
RUN cd build/packages && bash ./generate_package.sh "deb" "ubuntu-22.04" "amd64" \
    && mv "$( ls -t flon.cdt*.deb | head -1 )" /flon.cdt.deb
## create flon.cdt runtime env
FROM phusion/baseimage:jammy-1.0.4
RUN echo "deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse" >> /etc/apt/sources.list 

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y git clang \
    lldb libclang-dev cmake make automake libbz2-dev libssl-dev \
    libgmp3-dev autotools-dev build-essential libicu-dev python2.7-dev \
    autoconf libtool curl zlib1g-dev doxygen graphviz \
    libncurses5-dev libtinfo5 libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libcurl4-gnutls-dev

RUN mkdir -p /opt/flon.cdt
WORKDIR /opt/flon.cdt
COPY --from=0 /flon.cdt.deb /flon.cdt.deb
RUN apt install /flon.cdt.deb
RUN rm -rf /flon.cdt.deb