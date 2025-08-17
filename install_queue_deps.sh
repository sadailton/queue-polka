#!/bin/bash

WORKDIR=`echo $HOME`
PYTHON_MODULES="/usr/local/lib/python3.10/site-packages/"

#cd $WORKDIR

#git clone https://github.com/nerds-ufes/polka.git

pip3 install -r ./requirements.txt

sudo cp ./mininet_p4_queue.py $PYTHON_MODULES
