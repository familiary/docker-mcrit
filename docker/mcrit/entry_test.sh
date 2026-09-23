#!/bin/sh
set -eu
cd /opt/mcrit
# what `make test-nomongo` runs; called directly so the image needs no make
exec python -m pytest -m 'not mongo'
