#!/bin/env bash

LABNAME="porvir"
ROUTERS="clab-$LABNAME-edge1 clab-$LABNAME-edge2 clab-$LABNAME-edge3 clab-$LABNAME-edge4"

for ROUTER in $ROUTERS; do
    echo -n "Configurando rotas no switch ${ROUTER}...	"
    
    docker exec -it $ROUTER bash -c "source /mnt/pythonpath.sh; python3 /mnt/porvir/controller_edge.py"
    echo -e "[Ok]\n"

done