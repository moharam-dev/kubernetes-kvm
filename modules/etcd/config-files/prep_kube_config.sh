#!/bin/bash

VM_NAME=$1
IPADDRESS=$(ip address show | grep ens | awk '/inet / {split($2,var,"/*"); print var[1]}')

mkdir -p /run/k8-config

cat <<EOT >> /run/k8-config/kubeadmcfg.yaml
apiVersion: "kubeadm.k8s.io/v1beta2"
kind: ClusterConfiguration
etcd:
  local:
    serverCertSANs:
    - $IPADDRESS
    peerCertSANs:
    - $IPADDRESS
    extraArgs:
      initial-cluster: $VM_NAME=https://$IPADDRESS:2380
      initial-cluster-state: new
      name: $VM_NAME
      listen-peer-urls: https://$IPADDRESS:2380
      listen-client-urls: https://$IPADDRESS:2379
      advertise-client-urls: https://$IPADDRESS:2379
      initial-advertise-peer-urls: https://$IPADDRESS:2380
EOT

cd $ORIGINAL_DIR