#!/usr/bin/env bash
set -euo pipefail

validator="$(dirname "$0")/../scripts/validate-image-tag.sh"
preflight="$(dirname "$0")/../scripts/check-image-tag.sh"

for tag in 1.2.3 v1.2.3 1.2.3-rc.1 RC_1-foo.bar a; do
  bash "$validator" "$tag"
done

for tag in '' .1 -a 'a/b' 'has space' "$(printf 'x%.0s' {1..129})"; do
  if bash "$validator" "$tag" >/dev/null 2>&1; then
    echo "Invalid image tag was accepted: '$tag'" >&2
    exit 1
  fi
done

if bash "$validator" >/dev/null 2>&1; then
  echo 'Missing image tag was accepted.' >&2
  exit 1
fi

curl() {
  if [[ "$*" == *'/token?'* ]]; then
    [[ "$*" == *'test-actor:test-token'* ]] || return 1
    [[ "$*" == *'repository%3Ahelsingborg-stad%2Fapi.municipio.tech%3Apull'* ]] || return 1
    if [ "${FAKE_TOKEN_FAILURE:-false}" = true ]; then
      return 22
    fi
    printf '%s\n' '{"token":"test-token"}'
  else
    [[ "$*" == *'ghcr.io/v2/helsingborg-stad/api.municipio.tech/manifests/v1.2.3'* ]] || return 1
    [[ "$*" == *'Bearer test-token'* ]] || return 1
    if [ "${FAKE_REQUEST_FAILURE:-false}" = true ]; then
      return 7
    fi
    printf '%s' "$FAKE_STATUS"
  fi
}
export -f curl
export GH_TOKEN=test-token GITHUB_ACTOR=test-actor IMAGE_TAG=v1.2.3

FAKE_STATUS=404 bash "$preflight" >/dev/null
for status in 200 401 403 500; do
  if FAKE_STATUS="$status" bash "$preflight" >/dev/null 2>&1; then
    echo "GHCR HTTP $status did not fail closed." >&2
    exit 1
  fi
done

if FAKE_TOKEN_FAILURE=true FAKE_STATUS=404 bash "$preflight" >/dev/null 2>&1; then
  echo 'GHCR authentication failure did not fail closed.' >&2
  exit 1
fi

if FAKE_REQUEST_FAILURE=true FAKE_STATUS=404 bash "$preflight" >/dev/null 2>&1; then
  echo 'GHCR request failure did not fail closed.' >&2
  exit 1
fi

if IMAGE_TAG='invalid/tag' FAKE_STATUS=404 bash "$preflight" >/dev/null 2>&1; then
  echo 'GHCR preflight accepted an invalid tag.' >&2
  exit 1
fi

echo 'Image tag and GHCR preflight tests passed.'
