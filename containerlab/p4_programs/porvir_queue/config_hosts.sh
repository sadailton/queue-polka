#!/bin/env bash

# Script para configurar o MAC address e a tabela arp nos hosts

LABNAME="porvir_queue"

IP_HOST1="10.10.1.1"
IP_HOST2="10.10.1.2"
IP_HOST3="10.10.1.3"
IP_HOST4="10.10.1.4"

MAC_HOST1="aa:c1:ab:bc:94:f1"
MAC_HOST2="aa:c1:ab:f7:7c:77"
MAC_HOST3="aa:c1:ab:05:0f:f0"
MAC_HOST4="aa:c1:ab:cd:8c:e2"

IP_HOSTS=("10.10.1.1/24" "10.10.1.2/24" "10.10.1.3/24" "10.10.1.4/24")
MAC_HOSTS=("aa:c1:ab:bc:94:f1" "aa:c1:ab:f7:7c:77" "aa:c1:ab:05:0f:f0" "aa:c1:ab:cd:8c:e2")

num_elementos=${#IP_HOSTS[@]}

echo $num_elementos

echo -n "Configurando o endereço MAC dos hosts... "
# Desligando a interface de rede dos hosts
for (( i=0; i<num_elementos; i++)); do
    sudo ip netns exec clab-$LABNAME-host$((i+1)) ip link set dev eth1 down
done

# Atribuindo o endereço MAC na interface
for (( i=0; i<num_elementos; i++)); do
    sudo ip netns exec clab-$LABNAME-host$((i+1)) ip link set dev eth1 address ${MAC_HOSTS[i]}
done

# Levantando a interface de rede
for (( i=0; i<num_elementos; i++)); do
    sudo ip netns exec clab-$LABNAME-host$((i+1)) ip link set dev eth1 up
done

# Atribuindo o endereço IP
for (( i=0; i<num_elementos; i++)); do
    sudo ip netns exec clab-$LABNAME-host$((i+1)) ip addr add ${IP_HOSTS[i]} dev eth1
done

echo -e "[Ok]\n"

echo -n "Configurando tabela arp nos hosts...	"
sudo ip netns exec clab-$LABNAME-host1 arp -s $IP_HOST2 $MAC_HOST2
sudo ip netns exec clab-$LABNAME-host1 arp -s $IP_HOST3 $MAC_HOST3
sudo ip netns exec clab-$LABNAME-host1 arp -s $IP_HOST4 $MAC_HOST4

sudo ip netns exec clab-$LABNAME-host2 arp -s $IP_HOST1 $MAC_HOST1
sudo ip netns exec clab-$LABNAME-host2 arp -s $IP_HOST3 $MAC_HOST3
sudo ip netns exec clab-$LABNAME-host2 arp -s $IP_HOST4 $MAC_HOST4

sudo ip netns exec clab-$LABNAME-host3 arp -s $IP_HOST1 $MAC_HOST1
sudo ip netns exec clab-$LABNAME-host3 arp -s $IP_HOST2 $MAC_HOST2
sudo ip netns exec clab-$LABNAME-host3 arp -s $IP_HOST4 $MAC_HOST4

sudo ip netns exec clab-$LABNAME-host4 arp -s $IP_HOST1 $MAC_HOST1
sudo ip netns exec clab-$LABNAME-host4 arp -s $IP_HOST2 $MAC_HOST2
sudo ip netns exec clab-$LABNAME-host4 arp -s $IP_HOST3 $MAC_HOST3
echo "[Ok]"

echo "$IP_HOST1 - $MAC_HOST1"
echo "$IP_HOST2 - $MAC_HOST2"
echo "$IP_HOST3 - $MAC_HOST3"
echo "$IP_HOST4 - $MAC_HOST4"


