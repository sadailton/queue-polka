#!/bin/env bash

# Script to initialize the Tofino switch in Containerlab

P4_PROGRAM_DIR="/mnt/porvir"
P4_PROGRAM="polka_edge"
ARCH="tofino2"
PORT_INFO_FILE="${P4_PROGRAM_DIR}/portinfo_if.json"


echo "Starting Tofino model...   "
$SDE/run_tofino_model.sh -p $P4_PROGRAM --arch $ARCH -f $PORT_INFO_FILE &
echo -e "Tofino model started."
sleep 5


echo "Starting switchd...   "
$SDE/run_switchd.sh -p $P4_PROGRAM --arch $ARCH
echo -e "switchd started."
