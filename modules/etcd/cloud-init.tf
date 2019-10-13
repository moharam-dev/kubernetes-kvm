data "template_file" "meta_data" {
  template = <<EOT
    local-hostname: ${var.name}.k8.local
  EOT
}

# standalone etcd .. no culster yet
data "template_file" "user_data" {
  template = <<EOT
#cloud-config

preserve_hostname: true
ssh_pwauth: true

# passwd: password
users:
  - name: k8
    plain_text_passwd: "${var.common_password}"
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [users, admin, docker]
    shell: /bin/bash
    lock_passwd: false

write_files:
  - path: /tmp/get_config_files.sh
    content: |
      #!/bin/bash
      mkdir /media/config-iso
      mount /dev/sr0 /media/config-iso
      cp /media/config-iso/* /tmp/  
            
runcmd:
  # copy files and scripts from our config cdrom
  - chmod +x /tmp/get_config_files.sh && /tmp/get_config_files.sh

  # wait for DNS server to come up
  - chmod +x /tmp/wait_for_dependencies.sh && /tmp/wait_for_dependencies.sh ${var.dns_server} ${var.common_password}

  # disable system DNS resolver
  - systemctl disable systemd-resolved
  - systemctl stop systemd-resolved

  # set correct hostname and hosts file
  - hostnamectl set-hostname ${var.name}.k8.local
  - rm /etc/resolv.conf
  - echo "nameserver ${var.dns_server}" > /etc/resolv.conf 
  - echo "search k8.local"
  - echo "127.0.0.1 ${var.name} ${var.name}.k8.local localhost" > /etc/hosts

   # install etcd
  - apt update && apt-get -y install wget
  - ufw allow proto tcp from any to any port 2379,2380

  # install docker
  - apt remove -y docker docker-engine docker.io containerd runc
  - apt update
  - apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  - apt update
  - apt install -y docker-ce docker-ce-cli containerd.io

  # k8 setup
  - curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  - echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list
  - apt update
  - apt install -y kubeadm kubelet
  - systemctl enable kubelet

  # make kubelet the service manager for etcd
  - cp /tmp/20-etcd-service-manager.conf /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
  - systemctl daemon-reload
  - systemctl restart kubelet

  # create certificates 
  - chmod +x /tmp/prep_kube_config.sh && /tmp/prep_kube_config.sh ${var.name}

  - kubeadm init phase certs etcd-ca
  - kubeadm init phase certs etcd-server --config=/run/k8-config/kubeadmcfg.yaml
  - kubeadm init phase certs etcd-peer --config=/run/k8-config/kubeadmcfg.yaml
  - kubeadm init phase certs etcd-healthcheck-client --config=/run/k8-config/kubeadmcfg.yaml
  - kubeadm init phase certs apiserver-etcd-client --config=/run/k8-config/kubeadmcfg.yaml

  - kubeadm init phase etcd local --config=/run/k8-config/kubeadmcfg.yaml

  - cp /etc/kubernetes/pki/etcd/ca.crt /home/k8/ca.crt
  - cp /etc/kubernetes/pki/apiserver-etcd-client.crt /home/k8/apiserver-etcd-client.crt
  - cp /etc/kubernetes/pki/apiserver-etcd-client.key /home/k8/apiserver-etcd-client.key
  - chown -R k8:k8 /home/k8/
  
  # register in dns
  - chmod +x /tmp/register_in_dns.sh && /tmp/register_in_dns.sh ${var.name} ${var.common_password}
  
  EOT
}

/*
docker run --rm -it \
--net host \
-v /etc/kubernetes:/etc/kubernetes quay.io/coreos/etcd:v3.3.15 etcdctl \
--cert-file /etc/kubernetes/pki/etcd/peer.crt \
--key-file /etc/kubernetes/pki/etcd/peer.key \
--ca-file /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://192.168.3.103:2379 cluster-health

*/