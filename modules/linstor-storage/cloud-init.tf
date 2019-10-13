
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
  
  # install linstor
  - apt update 
  - apt install -y linux-headers-$(uname -r)
  - add-apt-repository -y ppa:linbit/linbit-drbd9-stack
  - apt update

  # install kernel modules
  - echo "postfix postfix/mailname string linstor.k8.local" | debconf-set-selections
  - echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
  - apt install -y drbd-utils drbd-dkms lvm2
  - modprobe drbd
  - echo drbd > /etc/modules-load.d/drbd.conf

  # setup as dual (controller and client)
  - apt install -y linstor-controller linstor-satellite linstor-client
  - systemctl enable --now linstor-controller
  - systemctl start linstor-controller
  
  # relax and setup linstor
  - sleep 30 
  - chmod +x /tmp/linstor_setup.sh && /tmp/linstor_setup.sh ${var.name}

  # register in dns
  - chmod +x /tmp/register_in_dns.sh && /tmp/register_in_dns.sh ${var.name} ${var.common_password}

  EOT
}
