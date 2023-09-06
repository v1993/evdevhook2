ARG UBUNTU_RELEASE=jammy

FROM ubuntu:$UBUNTU_RELEASE AS build-stage
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      git ca-certificates build-essential libudev-dev libevdev-dev zlib1g-dev valac libgee-0.8-dev meson

COPY . /

ARG BUILD_TYPE=release
ARG ENABLE_LTO=true

RUN meson setup \
      "--buildtype=${BUILD_TYPE}" \
      "-Db_lto=${ENABLE_LTO}" \
      "--prefix=/usr" \
      /build && \
    meson compile -C /build && \
    meson install --destdir="/release/$(uname -m)" -C /build

FROM scratch AS export-stage

COPY --from=build-stage /release/ /
