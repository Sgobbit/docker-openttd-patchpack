# BUILD ENVIRONMENT 1
FROM debian:latest AS ottd_build

ARG OPENTTD_VERSION="jgrpp-0.36.0"
ARG OPENGFX_VERSION="0.6.0"

# Get things ready
RUN mkdir -p /config \
    && mkdir /tmp/src

# Install build dependencies
RUN apt-get update && \
    apt-get install -y \
    unzip \
    wget \
    git \
    g++ \
    make \
    patch \
    zlib1g-dev \
    liblzma-dev \
    liblzo2-dev \
    pkg-config

# Build OpenTTD itself
WORKDIR /tmp/src

RUN git clone https://github.com/JGRennison/OpenTTD-patches . \
    && git fetch --tags \
    && git checkout ${OPENTTD_VERSION}

RUN /tmp/src/configure \
    --enable-dedicated \
    --binary-dir=bin \
    --data-dir=data \
    --prefix-dir=/app \
    --personal-dir=/ \
    —-enable-debug

RUN make -j"$(nproc)" \
    && make install

# Add the latest graphics files
## Install OpenGFX
RUN mkdir -p /app/data/baseset/ \
    && cd /app/data/baseset/ \
    && wget -q http://bundles.openttdcoop.org/opengfx/releases/${OPENGFX_VERSION}/opengfx-${OPENGFX_VERSION}.zip \
    && unzip opengfx-${OPENGFX_VERSION}.zip \
    && tar -xf opengfx-${OPENGFX_VERSION}.tar \
    && rm -rf opengfx-*.tar opengfx-*.zip

# END BUILD ENVIRONMENT 1
# BUILD ENVIRONMENT 2
FROM golang:alpine AS banread_build

# Install git.
# Git is required for fetching the dependencies.
RUN apk update && apk add --no-cache git

# Fetch banread and build the binary
RUN go get github.com/ropenttd/docker_openttd-bans-sidecar/pkg/banread \
    && go build -o /go/bin/banread github.com/ropenttd/docker_openttd-bans-sidecar/pkg/banread

# END BUILD ENVIRONMENTS
# DEPLOY ENVIRONMENT

FROM debian:latest
LABEL maintainer="Sgobbi Federico federico@sgobbi.it"

# Setup the environment and install runtime dependencies
RUN mkdir -p /config \
    && useradd -d /config -u 911 -s /bin/false openttd \
    && apt-get update \
    && apt-get install -y \
    libc6 \
    zlib1g \
    liblzma5 \
    liblzo2-2

WORKDIR /config

# Copy the game data from the build container
COPY --from=ottd_build /app /app

# And the banread executable from its build container
COPY --from=banread_build /go/bin/banread /usr/local/bin/banread

# Add the entrypoint
ADD entrypoint.sh /usr/local/bin/entrypoint

# Expose the volume
RUN chown -R openttd:openttd /config /app
VOLUME /config

# Expose the gameplay port
EXPOSE 3979/tcp
EXPOSE 3979/udp

# Expose the admin port
EXPOSE 3977/tcp

# Finally, let's run OpenTTD!
USER openttd
CMD /usr/local/bin/entrypoint
