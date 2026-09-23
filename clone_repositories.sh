#!/bin/bash

# Clone or update mcritweb
if [ ! -d "./repositories/mcritweb" ]; then
    git clone https://github.com/familiary/mcritweb.git ./repositories/mcritweb
else
    cd ./repositories/mcritweb && git pull && cd ../..
fi

# Clone or update mcrit
if [ ! -d "./repositories/mcrit" ]; then
    git clone https://github.com/familiary/mcrit.git ./repositories/mcrit
else
    cd ./repositories/mcrit && git pull && cd ../..
fi