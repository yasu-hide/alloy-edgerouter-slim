#!/bin/bash
# Fetch the latest alloy build from this repo's GitHub Release and swap it in.
# All temp files stay in the work dir so the final mv is a same-filesystem rename.
set -euo pipefail

cd "$(dirname "$0")"

BASE=https://github.com/yasu-hide/alloy-edgerouter-slim/releases/latest/download
NAME=alloy-linux-mips64-softfloat.gz
SERVICE=grafana-alloy
SETTLE_SECONDS=10
# Release public key, installed by hand next to this script. Never downloaded from GitHub.
PUBKEY=alloy-update.pub

# Scratch dir on the same filesystem as alloy, so the final mv is a rename.
# Literal ".tmp" on purpose (never a variable); safe because the cd above succeeded.
# Start clean: a killed run (SIGKILL/timeout) skips the trap and may leave .tmp behind.
rm -rf -- .tmp
mkdir -m 0700 .tmp
trap 'rm -rf -- .tmp' EXIT

# Fail early (before downloading anything) if the offline-signing public key is missing.
if [ ! -s "$PUBKEY" ]; then
  echo "alloy-update: public key $PUBKEY not found next to the script; refusing to update" >&2
  exit 1
fi

# The .sha256 file refers to "$NAME", so save the archive under that name.
curl -fsSL --retry 3 --connect-timeout 30 -o ".tmp/$NAME" "$BASE/$NAME"
curl -fsSL --retry 3 --connect-timeout 30 -o ".tmp/$NAME.sha256" "$BASE/$NAME.sha256"
(cd .tmp && sha256sum -c "$NAME.sha256")

# The signature (made offline, key never on GitHub) is what makes the archive trusted;
# the sha256 above only detects corruption. A missing .sig (not yet signed) 404s here.
curl -fsSL --retry 3 --connect-timeout 30 -o ".tmp/$NAME.sig" "$BASE/$NAME.sig"
if ! openssl dgst -sha256 -verify "$PUBKEY" -signature ".tmp/$NAME.sig" ".tmp/$NAME"; then
  echo "alloy-update: signature verification failed" >&2
  exit 1
fi

gunzip -c ".tmp/$NAME" > .tmp/alloy.new
chown 0:102 .tmp/alloy.new
chmod 0755 .tmp/alloy.new

# Pre-flight: never stop the service for a binary that cannot even run.
if ! .tmp/alloy.new --version > /dev/null; then
  echo "alloy-update: pre-flight '.tmp/alloy.new --version' failed; service left untouched" >&2
  exit 1
fi

systemctl stop "$SERVICE"
mv .tmp/alloy.new alloy
systemctl start "$SERVICE"

# The unit has Restart=always, so a zero exit from "systemctl start" is not
# enough: require it to stay active with the same non-zero MainPID (no flapping).
pid_before=$(systemctl show -p MainPID --value "$SERVICE")
sleep "$SETTLE_SECONDS"
state=$(systemctl show -p ActiveState --value "$SERVICE")
pid_after=$(systemctl show -p MainPID --value "$SERVICE")
if [ "$state" != active ] || [ "$pid_before" = 0 ] || [ "$pid_before" != "$pid_after" ]; then
  echo "alloy-update: $SERVICE unhealthy after start (ActiveState=$state, MainPID $pid_before -> $pid_after)" >&2
  exit 1
fi

version=$(./alloy --version)
echo "alloy-update: updated and running: ${version%%$'\n'*}"
