ARG DISTRO=jammy

FROM ubuntu:$DISTRO AS build-stage
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      git ca-certificates build-essential libudev-dev libevdev-dev zlib1g-dev valac libgee-0.8-dev meson
COPY . /
ARG BUILD_TYPE=release
ARG ENABLE_LTO=true
ARG TARGETOS TARGETARCH TARGETVARIANT
RUN meson setup \
      "--fatal-meson-warnings" \
      "--buildtype=${BUILD_TYPE}" \
      "-Db_lto=${ENABLE_LTO}" \
      "--prefix=/release${TARGETOS:+/${TARGETOS}-${TARGETARCH}${TARGETVARIANT}}" \
      /build && \
    meson compile -C /build && \
    meson install -C /build

FROM scratch AS export-stage
COPY --from=build-stage /release/ /
