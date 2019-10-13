#!/bin/bash
DNS_SERVER=$1
PASSWORD=$2

ORIGINAL_DIR=$(pwd)

cd /tmp

URL="http://$DNS_SERVER:8081/api/v1/servers/localhost/zones/k8.local"
until curl -sf -H "X-API-Key: $PASSWORD" "$URL"; do echo -n "*"; sleep 1; done

# wait for etcd master to come up
until ping -c1 etcd1.k8.local >/dev/null 2>&1; do echo "waiting etcd -- "; sleep 5; systemd-resolve --flush-caches; done

# wait for storage manager to come up
until ping -c1 linstor.k8.local >/dev/null 2>&1; do echo "waiting linstor -- "; sleep 5; systemd-resolve --flush-caches; done

cd $ORIGINAL_DIR