#!/bin/sh
set -eu
cd /opt/mcritweb
export FLASK_APP=mcritweb
export FLASK_DEBUG=1
export MCRIT_DEFAULT_SERVER="http://mcrit-server:8000/"

if [ ! -f /opt/mcritweb/instance/mcritweb.sqlite ]; then
    flask init-db
fi
exec flask run --host 0.0.0.0
