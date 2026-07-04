#!/usr/bin/env bash
#
# build.sh - interactively build a kubeasz-sys-pkg image.
#
# Resulting image tag: easzlab/kubeasz-sys-pkg:${SYS_PKG_VER}_${SYSTEM_TYPE}
#   - SYSTEM_TYPE : chosen subdirectory name (e.g. ubuntu_22)
#   - SYS_PKG_VER : read from "ENV SYS_PKG_VER=..." in that Dockerfile
#
# Usage:
#   ./build.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

IMAGE_REPO="easzlab/kubeasz-sys-pkg"

# Collect subdirectories that contain a Dockerfile.
mapfile -t DIRS < <(
  find . -mindepth 2 -type f -name Dockerfile -printf '%h\n' \
    | sort -u \
    | sed 's|^\./||'
)

if [[ ${#DIRS[@]} -eq 0 ]]; then
  echo "No directories with a Dockerfile found under $SCRIPT_DIR" >&2
  exit 1
fi

echo "===== kubeasz-sys-pkg build ====="
echo "Available system types:"
INDENT="  "
for i in "${!DIRS[@]}"; do
  printf '%s%2d) %s\n' "$INDENT" "$((i + 1))" "${DIRS[$i]}"
done

DIR=""
while [[ -z "$DIR" ]]; do
  read -r -p "$(printf '%sSelect [1-%d]: ' "$INDENT" "${#DIRS[@]}")" CHOICE
  if [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= ${#DIRS[@]} )); then
    DIR="${DIRS[$((CHOICE - 1))]}"
    if [[ ! -d "$DIR" || ! -f "$DIR/Dockerfile" ]]; then
      echo "${INDENT}Invalid selection, please try again." >&2
      DIR=""
    fi
  else
    echo "${INDENT}Invalid selection, please try again." >&2
  fi
done

SYSTEM_TYPE="$DIR"
DOCKERFILE="$DIR/Dockerfile"

# Extract SYS_PKG_VER from the Dockerfile, e.g. "ENV SYS_PKG_VER=1.0.4" -> "1.0.4".
SYS_PKG_VER="$(
  grep -E '^ENV[[:space:]]+SYS_PKG_VER=' "$DOCKERFILE" \
    | head -n1 \
    | sed -E 's/^ENV[[:space:]]+SYS_PKG_VER=//' \
    | tr -d ' "'
)"

if [[ -z "$SYS_PKG_VER" ]]; then
  echo "Could not find SYS_PKG_VER in $DOCKERFILE" >&2
  exit 1
fi

TAG="${IMAGE_REPO}:${SYS_PKG_VER}_${SYSTEM_TYPE}"

cat <<EOF

Build summary
-------------
  SYSTEM_TYPE : $SYSTEM_TYPE
  SYS_PKG_VER : $SYS_PKG_VER
  TAG         : $TAG
  DOCKERFILE  : $DOCKERFILE
  CONTEXT     : $SCRIPT_DIR/$DIR

EOF

docker build \
  -t "$TAG" \
  -f "$DOCKERFILE" \
  "$DIR"

echo
echo "Build complete: $TAG"
