#!/bin/bash
DNS_SERVER=$1
PASSWORD=$2

ORIGINAL_DIR=$(pwd)

cd /tmp

URL="http://$DNS_SERVER:8081/api/v1/servers/localhost/zones/k8.local"
until curl -sf -H "X-API-Key: $PASSWORD" "$URL"; do echo -n "*"; sleep 5; done

cd $ORIGINAL_DIR