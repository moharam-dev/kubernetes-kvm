#!/bin/bash

VM_NAME=$1
PASSWORD=$2

ORIGINAL_DIR=$(pwd)
cd /tmp

IPADDRESS=$(ip address show | grep ens | awk '/inet / {split($2,var,"/*"); print var[1]}')

cat <<EOT >> dns_a_record.json
{
    "rrsets": [{
        "name": "$VM_NAME.k8.local.",
        "ttl": 120,
        "type": "A",
        "priority": 0,
        "changetype": "REPLACE",
        "records": [{
            "content": "$IPADDRESS",
            "disabled": false
        }]
    }]
}
EOT

curl -X PATCH --data-binary "@dns_a_record.json" -v -H "Content-Type: application/json" -H "X-API-Key: $PASSWORD" http://dns.k8.local:8081/api/v1/servers/localhost/zones/k8.local |
      
cd $ORIGINAL_DIR