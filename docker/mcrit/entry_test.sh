#!/bin/sh
# wait for mongodb
#until $(curl --noproxy '*' --output /dev/null --head --fail http://mongodb:27017/); do
#    echo "Waiting for mongodb..."
#    sleep 1
#done
sleep 1
cd /opt/mcrit
# MCRIT declares its test tooling as the "dev" extra, which a production image has no business
# carrying - install pytest here, where the CI functionality check is the only consumer. Before
# MCRIT 1.8.0 it arrived by accident, as requirements.txt still listed it as a runtime dependency.
python -m pip install -q pytest
make test-nomongo
