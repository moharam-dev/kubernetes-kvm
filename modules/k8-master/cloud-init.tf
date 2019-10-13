
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

  # relax
  - chmod +x /tmp/wait_for_dependencies.sh && /tmp/wait_for_dependencies.sh ${var.dns_server} ${var.common_password}

  # disable system DNS resolver
  - hostnamectl set-hostname ${var.name}.k8.local
  - systemctl disable systemd-resolved
  - systemctl stop systemd-resolved
  - rm /etc/resolv.conf
  - echo "nameserver ${var.dns_server}" > /etc/resolv.conf 
  - echo "search k8.local"
  - echo "127.0.0.1 ${var.name} ${var.name}.k8.local localhost" > /etc/hosts
  
  # install docker
  - apt remove -y docker docker-engine docker.io containerd runc
  - apt update
  - apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  - apt update
  - apt install -y docker-ce docker-ce-cli containerd.io

  # k8 prep
  - swapoff -a
  - echo 'y' | ufw reset
  - ufw disable

  # k8 setup
  - curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  - echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list
  - apt update
  - apt install -y kubeadm kubelet kubectl
  - systemctl enable kubelet

  # upload certs from etcd1
  - apt install -y sshpass 
  - sshpass -p ${var.common_password} scp -o StrictHostKeyChecking=no k8@etcd1.k8.local:ca.crt /home/k8/ca.crt
  - sshpass -p ${var.common_password} scp -o StrictHostKeyChecking=no k8@etcd1.k8.local:apiserver-etcd-client.crt /home/k8/apiserver-etcd-client.crt
  - sshpass -p ${var.common_password} scp -o StrictHostKeyChecking=no k8@etcd1.k8.local:apiserver-etcd-client.key  /home/k8/apiserver-etcd-client.key 
  - chown -R k8:k8 /home/k8/

  # init cluster
  - mkdir /run/k8-config
  - cp /tmp/kubeadm-config.yaml /run/k8-config/kubeadm-config.yaml
  - kubeadm init --config /run/k8-config/kubeadm-config.yaml --upload-certs
  - mkdir -p /home/k8/.kube
  - cp -i /etc/kubernetes/admin.conf /home/k8/.kube/config
  - chown k8:k8 /home/k8/.kube/config

  # install network provider
  - runuser -l k8 -c "kubectl apply -f /tmp/calico_cni.yaml"

  # install storage provider
  - runuser -l k8 -c "kubectl apply -f /tmp/linstor_csi.yaml"

  # register in dns
  - chmod +x /tmp/register_in_dns.sh && /tmp/register_in_dns.sh ${var.name} ${var.common_password}

  EOT
}
