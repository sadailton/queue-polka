#!/bin/env bash

LABNAME="polkalab"
ROUTES="clab-$LABNAME-edge1 clab-$LABNAME-edge2"

for ROUTE in $ROUTES; do
    echo -n "Configurando rotas no switch ${ROUTE}...	"
    
    docker exec -it $ROUTE bash -c "source /mnt/pythonpath.sh; python3 /mnt/polka/controller_edge.py"
    echo -e "[Ok]\n"

done