#! /bin/bash
VM_NAME=$1
PASSWORD=$2

ORIGINAL_DIR=$(pwd)
cd /tmp

# additional config for PowerDNS 
# https://doc.powerdns.com/authoritative/settings.html
cat <<EOT >> /etc/powerdns/pdns.conf

# switch to custom dns port
local-port = 5300

# turn on webserver
webserver=yes
webserver-address=0.0.0.0
webserver-allow-from=0.0.0.0/0,::/0

# default soa
default-soa-name=$VM_NAME.k8.local

# turn on api server
api=yes
api-key=$PASSWORD
EOT

# additional config for PowerDNS Recursor
# https://doc.powerdns.com/recursor/settings.html
cat <<EOT >> /etc/powerdns/recursor.conf
# DNS service
local-address=0.0.0.0
local-port = 53
allow-from=0.0.0.0/0

# map forwarders
forward-zones=k8.local=127.0.0.1:5300
forward-zones-recurse=.=8.8.8.8;8.8.4.4;9.9.9.9;149.112.112.112;1.1.1.1;64.6.64.6;64.6.65.6
trace=on
dnssec=off
max-cache-ttl=15
EOT

cd $ORIGINAL_DIR