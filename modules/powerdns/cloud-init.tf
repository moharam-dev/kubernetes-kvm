
data "template_file" "meta_data" {
  template = <<EOT
    local-hostname: dns.k8.local
  EOT
}

# referenece
# https://doc.powerdns.com/authoritative/guides/recursion.html
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
  
  - apt update

  # install mysql
  - apt -y install mysql-client
  - echo "mysql-server mysql-server/root_password password ${var.common_password}" | debconf-set-selections
  - echo "mysql-server mysql-server/root_password_again password ${var.common_password}" | debconf-set-selections
  - apt -y install mysql-server 
  
  # install powerDns (db is created automatically)
  - DEBIAN_FRONTEND=noninteractive apt -y install pdns-server pdns-recursor pdns-backend-mysql

  # turn off resolver and switch DNS
  - systemctl stop pdns
  - systemctl stop pdns-recursor
  - systemctl disable systemd-resolved
  - systemctl stop systemd-resolved
  - hostnamectl set-hostname ${var.name}.k8.local
  - rm /etc/resolv.conf
  - echo "nameserver 127.0.0.1" > /etc/resolv.conf
  - echo "search k8.local"
  - echo "127.0.0.1 dns dns.k8.local localhost" > /etc/hosts
  
  - chmod +x /tmp/prep_pdns_config.sh && /tmp/prep_pdns_config.sh ${var.name} ${var.common_password}
  - systemctl restart pdns
  - systemctl restart pdns-recursor

  # all good .. initialize DNS
  - chmod +x /tmp/create_local_zone.sh && /tmp/create_local_zone.sh ${var.name} ${var.common_password}
  EOT
}