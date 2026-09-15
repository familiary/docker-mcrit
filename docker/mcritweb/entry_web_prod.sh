#!/bin/sh
set -eu
cd /opt/mcritweb
export FLASK_APP=mcritweb
# app.debug is what decides SESSION_COOKIE_SECURE in mcritweb's create_app
export FLASK_DEBUG=0
export MCRIT_DEFAULT_SERVER="http://mcrit-server:8000/"

if [ ! -f /opt/mcritweb/instance/mcritweb.sqlite ]; then
    flask init-db
fi
exec gunicorn -w 2 -k gthread --threads 8 -t 300 -b 0.0.0.0:5000 "mcritweb:create_app()"
