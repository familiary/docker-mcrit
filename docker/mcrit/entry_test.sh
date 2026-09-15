#!/bin/sh
set -eu
# shellcheck source-path=SCRIPTDIR source=entry_common.sh
. /entry_common.sh
cd /opt/mcrit
# what `make test-nomongo` runs; called directly so the image needs no make
exec python -m pytest -m 'not mongo'
