#!/usr/bin/env bash
set -euo pipefail

bash "$(dirname "$0")/validate-image-tag.sh" "$IMAGE_TAG"

token=$(curl --silent --show-error --fail \
  --user "$GITHUB_ACTOR:$GH_TOKEN" \
  'https://ghcr.io/token?scope=repository%3Ahelsingborg-stad%2Fapi.municipio.tech%3Apull&service=ghcr.io' |
  jq -er '.token')
status=$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
  --header "Authorization: Bearer $token" \
  --header 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json' \
  "https://ghcr.io/v2/helsingborg-stad/api.municipio.tech/manifests/$IMAGE_TAG")

case "$status" in
  200)
    echo "Image tag $IMAGE_TAG already exists in GHCR; refusing to overwrite it." >&2
    exit 1
    ;;
  404)
    echo "Image tag $IMAGE_TAG is available."
    ;;
  *)
    echo "Cannot verify whether image tag $IMAGE_TAG exists (GHCR HTTP $status)." >&2
    exit 1
    ;;
esac
