#!/bin/bash
# Builds and pushes the CDE 1.26 HOL image. Run from anywhere: ./docker/build.sh [--no-push]
# Downloads the large binaries (cde CLI, pyspark tarball) from the GitHub Release if they are not present.

set -euo pipefail

IMAGE="pauldefusco/cde_126_hol"
VERSION="1.26.1"
ASSETS_URL="https://github.com/pdefusco/CDE_126_HOL/releases/download/v1.26-assets"
CDE_CLI_ASSET="cde-linux-amd64"
PYSPARK_TARBALL="pyspark-3.5.4.tar.gz"

cd "$(dirname "$0")/.."

mkdir -p bin spark-connect
if [ ! -f bin/cde ]; then
  curl -fL -o bin/cde "$ASSETS_URL/$CDE_CLI_ASSET"
fi
if [ ! -f "spark-connect/$PYSPARK_TARBALL" ]; then
  curl -fL -o "spark-connect/$PYSPARK_TARBALL" "$ASSETS_URL/$PYSPARK_TARBALL"
fi
if ! ls spark-connect/cdeconnect*.tar.gz >/dev/null 2>&1; then
  echo "Missing spark-connect/cdeconnect*.tar.gz (download it from the Spark Connect session's Connect tab)" >&2
  exit 1
fi

OUTPUT="--push"
if [ "${1:-}" = "--no-push" ]; then
  OUTPUT="--load"
fi

docker buildx build --platform linux/amd64 \
  -t "$IMAGE:$VERSION" -t "$IMAGE:latest" \
  $OUTPUT .
