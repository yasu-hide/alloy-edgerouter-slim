#!/usr/bin/env bash
# Usage: build.sh <upstream-tree-dir> <tag> <output-binary>
# Builds slim Alloy for EdgeRouter (linux/mips64 softfloat, static). Does NOT use `make alloy`.
# Env: REVISION (fallback commit sha when the tree is not a git checkout), NO_GORE2REGEX=1 to drop the tag.
set -euo pipefail

if [ $# -ne 3 ]; then echo "usage: $0 <upstream-tree-dir> <tag> <output-binary>" >&2; exit 2; fi
HERE=$(cd "$(dirname "$0")" && pwd)
TREE=$(realpath "$1")
TAG=$2
mkdir -p "$(dirname "$3")"
OUTBIN=$(realpath "$3")

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
"$HERE/gen-overlay.sh" "$TREE" "$WORK"

if REV=$(git -C "$TREE" rev-parse --short HEAD 2>/dev/null); then :; else REV=${REVISION:-unknown}; fi
BRANCH=$TAG
VP=github.com/grafana/alloy/internal/build
VPS=github.com/grafana/alloy/syntax/internal/stdlib
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LDFLAGS="-s -w -X $VP.Branch=$BRANCH -X $VP.Version=$TAG -X $VPS.Version=$TAG -X $VP.Revision=$REV -X $VP.BuildUser=github-actions@ci -X $VP.BuildDate=$BUILD_DATE"

TAGS=gore2regex   # parity with the official Makefile, which prepends it to GO_TAGS
[ "${NO_GORE2REGEX:-}" = 1 ] && TAGS=""

cd "$TREE/collector"
CGO_ENABLED=0 GOOS=linux GOARCH=mips64 GOMIPS64=softfloat \
  GOFLAGS="-mod=readonly -overlay=$WORK/overlay.json" \
  go build -tags "$TAGS" -ldflags "$LDFLAGS" -o "$OUTBIN" .
echo "build: wrote $OUTBIN (version=$TAG revision=$REV)" >&2
