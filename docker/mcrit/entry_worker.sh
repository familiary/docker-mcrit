#!/bin/sh
set -eu
cd /opt/mcrit
exec python -m mcrit worker
