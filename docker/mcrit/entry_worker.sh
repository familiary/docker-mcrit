#!/bin/sh
set -eu
# shellcheck source-path=SCRIPTDIR source=entry_common.sh
. /entry_common.sh
cd /opt/mcrit
exec python -m mcrit worker
