#!/bin/bash
# Local equivalent of the CI build test: build both images under the tags compose uses, then run
# MCRIT's own test suite inside the freshly built image.
set -euo pipefail
cd "$(dirname "$0")"

# shellcheck disable=SC1091
source .env

echo "building mcrit ${MCRIT_BRANCH} / mcritweb ${MCRITWEB_BRANCH} (mcrit tag: ${MCRIT_TAG})"
docker compose build mcrit-server mcritweb

echo "checking functionality of the MCRIT image"
docker run --rm --entrypoint /entry_test.sh "mcrit:${MCRIT_TAG}"
