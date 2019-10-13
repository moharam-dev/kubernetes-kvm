
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

  # prerequisites
  - apt update
  - apt install -y sshpass wget curl

  # install docker
  - apt remove -y docker docker-engine docker.io containerd runc
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
  
  # join the cluster
  # wait for master to be ready
  - until sshpass -p ${var.common_password} ssh -o StrictHostKeyChecking=no k8@master.k8.local "kubectl get nodes master.k8.local" | grep -m 1 "Ready"; do sleep 30; done
  - $(sshpass -p ${var.common_password} ssh -o StrictHostKeyChecking=no k8@master.k8.local "kubeadm token create --print-join-command")

  # register in dns
  - chmod +x /tmp/register_in_dns.sh && /tmp/register_in_dns.sh ${var.name} ${var.common_password}
  EOT
}