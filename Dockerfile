# syntax=docker/dockerfile:1

FROM ubuntu:24.10 AS gcc_build

# Build GCC RISC-V
RUN <<EOT
apt update
apt install -y git curl
git clone https://github.com/lukstep/raspberry-pi-pico-docker-sdk.git
cp raspberry-pi-pico-docker-sdk/install_gcc.sh /home/install_gcc.sh
EOT

RUN bash /home/install_gcc.sh

# Okay Theres some github actions and node related things that happen first, so we'll also need to build those
# Install node first
ENV NODE_VERSION=20.19.2
ENV NVM_DIR=/root/.nvm
RUN mkdir -p $NVM_DIR

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION} && nvm use v${NODE_VERSION} && nvm alias default v${NODE_VERSION}
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"

FROM debian:bookworm-slim AS sdk_setup
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
                       git \
                       ca-certificates \
                       python3 \
                       tar \
                       build-essential \
                       gcc-arm-none-eabi \
                       libnewlib-arm-none-eabi \
                       libstdc++-arm-none-eabi-newlib \
                       cmake \
                       curl \
                       python3-venv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG SDK_PATH=/usr/local/picosdk
RUN git clone --branch master https://github.com/raspberrypi/pico-sdk $SDK_PATH && \
    cd $SDK_PATH && \
    git submodule update --init

ENV PICO_SDK_PATH=$SDK_PATH

# FreeRTOS
#ARG FREERTOS_PATH=/usr/local/freertos
#COPY --from=devenv $FREERTOS_PATH $FREERTOS_PATH

#RUN git clone --depth 1 --branch V11.2.0 https://github.com/FreeRTOS/FreeRTOS-Kernel $FREERTOS_PATH && \
#    cd $FREERTOS_PATH && \
#    git submodule update --init --recursive

#ENV FREERTOS_KERNEL_PATH=$FREERTOS_PATH

# Picotool installation
#RUN git clone --depth 1 --branch 2.1.1 https://github.com/raspberrypi/picotool.git /home/picotool && \
#    cd /home/picotool && \
#    mkdir build && \
#    cd build && \
#    cmake .. && \
#    make -j$(nproc) && \
#    cmake --install . && \
#    rm -rf /home/picotool

# Install GCC RISC-V
COPY --from=gcc_build /opt/riscv/gcc14-rp2350-no-zcmp /opt/riscv/gcc14-rp2350-no-zcmp
ENV PATH="$PATH:/opt/riscv/gcc14-rp2350-no-zcmp/bin"

ENV NODE_VERSION=18.20.8
ENV NVM_DIR=/root/.nvm

RUN mkdir -p $NVM_DIR
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"

RUN <<EOT
git clone https://github.com/OpenStickCommunity/GP2040-CE.git
cd GP2040-CE
git submodule update --init
EOT

#COPY --from=gcc_build /lib/httpd/fsdata.c /GP2040-CE/lib/httpd/fsdata.c

# ARG SKIP_WEBBUILD=TRUE

RUN <<EOT
cd GP2040-CE
mkdir build
cd build
cmake ..
make
make clean
EOT
