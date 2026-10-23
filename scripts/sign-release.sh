#!/usr/bin/env bash
# Usage: sign-release.sh <tag> <private-key.pem>
# Run on the maintainer's machine. Downloads the Release archives, checks their sha256,
# signs each .gz offline (ECDSA P-256 / SHA-256, DER), self-verifies, and PRINTS the
# `gh release upload` command. It never uploads: that is an outward action for the maintainer.
set -euo pipefail

if [ $# -ne 2 ]; then echo "usage: $0 <tag> <private-key.pem>" >&2; exit 2; fi
TAG=$1
KEY=$(realpath "$2")
[ -f "$KEY" ] || { echo "ERROR: private key $KEY not found" >&2; exit 1; }

WORK=$(mktemp -d)
# Kept on success so the printed upload command can reference the .sig files; removed on failure.
trap 'rc=$?; [ "$rc" -eq 0 ] || rm -rf "$WORK"' EXIT

gh release download "$TAG" --dir "$WORK" \
  --pattern "alloy-linux-mips64-softfloat.gz" --pattern "alloy-linux-mips64-softfloat.gz.sha256" \
  --pattern "alloy-${TAG}-linux-mips64-softfloat.gz" --pattern "alloy-${TAG}-linux-mips64-softfloat.gz.sha256"

# Public key derived from the private key, used only for the self-check below.
openssl ec -in "$KEY" -pubout -out "$WORK/pub.pem" 2>/dev/null

UPLOAD=()
for f in "alloy-linux-mips64-softfloat.gz" "alloy-${TAG}-linux-mips64-softfloat.gz"; do
  (cd "$WORK" && sha256sum -c "$f.sha256")
  openssl dgst -sha256 -sign "$KEY" -out "$WORK/$f.sig" "$WORK/$f"
  openssl dgst -sha256 -verify "$WORK/pub.pem" -signature "$WORK/$f.sig" "$WORK/$f"
  UPLOAD+=("$WORK/$f.sig")
done

echo "sign-release: signed and self-verified. Review, then run:" >&2
echo "gh release upload $TAG $(printf '%q ' "${UPLOAD[@]}")" >&2
