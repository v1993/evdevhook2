# syntax=docker/dockerfile:1
FROM ghcr.io/pkgforge-dev/archlinux AS build-stage

# Install project dependencies
RUN pacman -Syu --noconfirm meson base-devel vala git libgee libevdev

# Build project
COPY . /project
WORKDIR /project
ARG BUILD_TYPE=release
ARG ENABLE_LTO=true
ARG TARGETOS TARGETARCH TARGETVARIANT
ARG VERSION
RUN <<EOF
  set -eu

  meson rewrite kwargs set project / version "${VERSION:-$(git describe --tags --always)}"
  meson setup \
      --fatal-meson-warnings \
      "--buildtype=${BUILD_TYPE}" \
      "-Db_lto=${ENABLE_LTO}" \
      --prefix=/usr \
      /build
  meson compile -C /build
  meson install --destdir=/ -C /build
EOF

# Build AppImage
ARG APP_NAME=evdevhook2
ARG OWNER=owner
ARG SHARUN_URL=https://github.com/pkgforge-dev/Anylinux-AppImages/raw/refs/heads/main/useful-tools/quick-sharun.sh

RUN <<EOF
  set -eu
  pacman -Syu --noconfirm patchelf xorg-server-xvfb

  arch="$(uname -m)"
  export DESKTOP="dist/${APP_NAME}.desktop"
  export ICON="dist/${APP_NAME}.png"
  export VERSION="$("${APP_NAME}" --version | grep -o '[^ ]\+$')"
  export OUTNAME="${APP_NAME}-${VERSION}-${arch}.AppImage"
  export OUTPATH=/appimage
  export UPINFO="gh-releases-zsync|${OWNER}|${APP_NAME}|latest|${APP_NAME}-*-${arch}.AppImage.zsync"

  curl -fsSL "${SHARUN_URL}" | install /dev/stdin ./quick-sharun.sh
  test -s ./quick-sharun.sh
  ./quick-sharun.sh "/usr/bin/${APP_NAME}"
  ./quick-sharun.sh --make-appimage
EOF

FROM scratch AS export-stage
COPY --from=build-stage /appimage/* /
