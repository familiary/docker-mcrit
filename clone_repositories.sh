#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Clone or update mcritweb
if [ ! -d "./repositories/mcritweb" ]; then
    git clone https://github.com/fkie-cad/mcritweb.git ./repositories/mcritweb
else
    git -C ./repositories/mcritweb pull
fi

# Clone or update mcrit
if [ ! -d "./repositories/mcrit" ]; then
    git clone https://github.com/danielplohmann/mcrit.git ./repositories/mcrit
else
    git -C ./repositories/mcrit pull
fi
