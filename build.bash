#!/bin/bash
# Icinga Web 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+
set -exo pipefail

IW2SRC="$1"
export BUILD_MODE="${2:-release}"
ACTION="${3:-local}"
IMAGE="${4:-docker.io/icinga/icingaweb2}"
TAG="${5:-$(date -u +'%Y%m%d%H%M%S')}"

if [ -z "$IW2SRC" ]; then
	cat <<EOF >&2
Usage: ${0} /icingaweb2/source/dir [release|snapshot [local|all|push|digest [IMAGE] [TAG]]]
Defaults: release local docker.io/icinga/icingaweb2 \$DATE

digest: push untagged by digest (for merging per-platform builds into one tag
        afterwards), writing build metadata to \$METADATA_FILE.
Env: PLATFORMS overrides platforms.txt.
EOF

	false
fi

if ! docker version; then
	echo 'Docker not found' >&2
	false
fi

if ! docker buildx version; then
	echo '"docker buildx" not found (see https://docs.docker.com/buildx/working-with-buildx/ )' >&2
	false
fi

OUR_DIR="$(realpath "$(dirname "$0")")"
BUILD_ARGS=(--build-context "icingaweb2-git=$(realpath "$IW2SRC")/.git/" --build-arg "BUILD_MODE=$BUILD_MODE" --build-arg "MODULES_AS_OF=${MODULES_AS_OF:-}" --build-arg "ICINGAWEB2_REVISION=$(git -C "$IW2SRC" rev-parse HEAD)" --build-arg "IMAGE_SOURCE=${IMAGE_SOURCE:-}" "$OUR_DIR")
COMMON_ARGS=(-t "$IMAGE:$TAG" "${BUILD_ARGS[@]}")
BUILDX=(docker buildx build --platform "${PLATFORMS:-$(cat "${OUR_DIR}/platforms.txt")}")

case "$ACTION" in
	all)
		"${BUILDX[@]}" "${COMMON_ARGS[@]}"
		;;
	push)
		"${BUILDX[@]}" --push "${COMMON_ARGS[@]}"
		;;
	digest)
		"${BUILDX[@]}" --output "type=image,name=${IMAGE},push-by-digest=true,name-canonical=true,push=true" \
			--metadata-file "${METADATA_FILE:?METADATA_FILE must be set}" "${BUILD_ARGS[@]}"
		;;
	*)
		docker buildx build --load "${COMMON_ARGS[@]}"
		;;
esac
