#!/usr/bin/env bash
# Usage: select-tag.sh [explicit-tag]
# Prints the upstream grafana/alloy stable tag to build, or nothing (exit 0) if none.
# Requires: git, gh (GH_TOKEN), sort -V. Env: FORCE=1 bypasses the "already released here" check
# for an explicit tag. MIN_TAG (default v1.21.0). UPSTREAM_REPO (default grafana/alloy).
set -euo pipefail

UPSTREAM=${UPSTREAM_REPO:-grafana/alloy}
MIN=${MIN_TAG:-v1.21.0}
EXPLICIT=${1:-}

is_ge_min() { [ "$(printf '%s\n%s\n' "$MIN" "$1" | sort -V | head -n1)" = "$MIN" ]; }

# (c) published, non-draft, non-prerelease upstream Release looked up BY TAG (list tag_name is unreliable).
upstream_released() {
  local out
  out=$(gh api "repos/$UPSTREAM/releases/tags/$1" --jq '[.draft, .prerelease, .tag_name] | @tsv' 2>/dev/null) || return 1
  [ "$out" = "$(printf 'false\tfalse\t%s' "$1")" ]
}

# (d) true if THIS repo already has a Release for the tag. If the check itself fails
# (e.g. no repo/remote yet, or no auth), treat as "no release" and continue.
own_released() {
  local err
  if err=$(gh release view "$1" 2>&1 >/dev/null); then return 0; fi
  case "$err" in
    *"release not found"*) return 1 ;;
    *) echo "select-tag: warn: own-release check failed ($err); assuming not released" >&2; return 1 ;;
  esac
}

re='^v[0-9]+\.[0-9]+\.[0-9]+$'
if [ -n "$EXPLICIT" ]; then
  [[ $EXPLICIT =~ $re ]] || { echo "select-tag: '$EXPLICIT' is not a stable vX.Y.Z tag" >&2; exit 1; }
  is_ge_min "$EXPLICIT" || { echo "select-tag: $EXPLICIT < $MIN" >&2; exit 1; }
  git ls-remote --exit-code --tags "https://github.com/$UPSTREAM" "refs/tags/$EXPLICIT" >/dev/null \
    || { echo "select-tag: tag $EXPLICIT not found upstream" >&2; exit 1; }
  upstream_released "$EXPLICIT" || { echo "select-tag: $EXPLICIT has no published upstream Release" >&2; exit 1; }
  if [ "${FORCE:-}" != 1 ] && own_released "$EXPLICIT"; then
    echo "select-tag: $EXPLICIT already released here (set FORCE=1 to override)" >&2; exit 0
  fi
  echo "$EXPLICIT"; exit 0
fi

tags=$(git ls-remote --tags "https://github.com/$UPSTREAM" \
  | awk '{print $2}' | grep -v '\^{}$' | sed 's#^refs/tags/##' | grep -E "$re" | sort -V)

# Newest first; the first tag passing (b)(c)(d) wins.
for t in $(printf '%s\n' "$tags" | sort -rV); do
  is_ge_min "$t" || break
  if ! upstream_released "$t"; then echo "select-tag: skip $t (no published upstream Release)" >&2; continue; fi
  if own_released "$t"; then echo "select-tag: $t already released here; nothing newer to build" >&2; exit 0; fi
  echo "$t"; exit 0
done
exit 0
