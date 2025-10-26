#!/bin/env bash

LABNAME="polkalab"

IP_HOST1="10.10.1.1"
IP_HOST2="10.10.1.2"

MAC_HOST1=$(sudo ip netns exec clab-$LABNAME-host1 ip addr s dev eth1 | grep "link/ether" | awk '{ print $2}')
MAC_HOST2=$(sudo ip netns exec clab-$LABNAME-host2 ip addr s dev eth1 | grep "link/ether" | awk '{ print $2}')

echo -e "Configurando tabela arp nos hosts...	"
sudo ip netns exec clab-$LABNAME-host1 arp -s $IP_HOST2 $MAC_HOST2
sudo ip netns exec clab-$LABNAME-host2 arp -s $IP_HOST1 $MAC_HOST1

echo "$IP_HOST1 - $MAC_HOST1"
echo "$IP_HOST2 - $MAC_HOST2"

echo "[Ok]"
