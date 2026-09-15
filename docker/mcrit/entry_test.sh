#!/bin/sh
set -eu
cd /opt/mcrit
# MCRIT declares its test tooling as the "dev" extra, which a production image has no business
# carrying - install pytest here, where the CI functionality check is the only consumer. Before
# MCRIT 1.8.0 it arrived by accident, as requirements.txt still listed it as a runtime dependency.
python -m pip install -q pytest
exec make test-nomongo
