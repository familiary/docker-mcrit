#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# mcrit-worker shares mcrit-server's image and has no build block of its own
docker compose build mcrit-server mcritweb
