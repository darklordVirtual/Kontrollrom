#!/bin/bash

# Kontroller at scriptet kjøres som root
if [ "$(id -u)" != "0" ]; then
   echo "Dette scriptet må kjøres som root" 1>&2
   exit 1
fi

# Oppdater systemet og installer nødvendige pakker
apt-get update && apt-get upgrade -y
apt-get install -y iptables iptables-persistent pppoe-server pppoeconf

# Sett opp PPPoE-serveren
cat <<EOT > /etc/ppp/pppoe-server-options
require-pap
login
lcp-echo-interval 10
lcp-echo-failure 2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
EOT

cat <<EOT > /etc/ppp/chap-secrets
# Secrets for PPPoE authentication
# Format: [username] [server] [password] [ip_address]
user1   *       password1      10.0.0.2
user2   *       password2      10.0.0.3
EOT

cat <<EOT > /etc/default/pppoe-server
INTERFACES="eth0"
EOT

# Sett opp CGNAT
WAN_IF="eth1"
LAN_IP_RANGE="10.0.0.0/24"
CGNAT_IP_RANGE="100.64.0.0/10"

echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -s $LAN_IP_RANGE -o $WAN_IF -j SNAT --to-source $CGNAT_IP_RANGE

iptables-save > /etc/iptables/rules.v4

# Start og aktiver tjenestene
systemctl enable pppoe-server
systemctl start pppoe-server

# Sjekk og valider oppsettet
SERVER_PORT=20000
nc -zv -w5 127.0.0.1 $SERVER_PORT

systemctl is-active pppoe-server.service
iptables -t nat -L POSTROUTING

echo "Serveren er klar for tilkobling av klienter"
