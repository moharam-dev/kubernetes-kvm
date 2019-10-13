#!/bin/bash
IPADDRESS=$(ip address show | grep ens | awk '/inet / {split($2,var,"/*"); print var[1]}')
VM_NAME=$1
PASSWORD=$2

ORIGINAL_DIR=$(pwd)
cd /tmp

# first create our local zone 
cat <<EOT > zone.json
{	
    "name": "k8.local.",	
    "type": "Zone", 
    "kind": "Native",	
    "nameservers": ["$VM_NAME.k8.local."] 
}
EOT

curl -X POST --data-binary "@zone.json" -v -H "Content-Type: application/json" -H "X-API-Key: $PASSWORD" http://$IPADDRESS:8081/api/v1/servers/localhost/zones

# our vm is slow .. relax it a bit
sleep 5 
until curl -sf -H "X-API-Key: $PASSWORD" "http://$IPADDRESS:8081/api/v1/servers/localhost/zones/k8.local"; do echo -n "*"; sleep 5; done

# second create the name server A record
cat <<EOT > ns.json
{ 
    "rrsets": [{  
        "name": "$VM_NAME.k8.local.",  
        "type": "A",  
        "changetype": "REPLACE",  
        "ttl": "86400", 
        "records": [{ 
            "content": "$IPADDRESS", 
            "disabled": false,  
            "priority": 0 
        }]
    }]
}
EOT
curl -X PATCH --data-binary "@ns.json" -v -H "Content-Type: application/json" -H "X-API-Key: $PASSWORD" http://$IPADDRESS:8081/api/v1/servers/localhost/zones/k8.local

cd $ORIGINAL_DIR