#!/bin/sh
set -eu
cd /opt/mcritweb
export FLASK_APP=mcritweb
export FLASK_DEBUG=1
export MCRIT_DEFAULT_SERVER="http://mcrit-server:8000/"

# instance/ is a host bind mount, so its ownership comes from the host and not from the image
if [ ! -w /opt/mcritweb/instance ]; then
    echo "instance directory is not writable by uid $(id -u); run: chown -R 10001:10001 storage/mcritweb" >&2
    exit 1
fi

if [ ! -f /opt/mcritweb/instance/mcritweb.sqlite ]; then
    flask init-db
fi
exec flask run --host 0.0.0.0
