data "template_file" "network_config" {
  template = <<EOT
# fixed ip address
version: 2
ethernets:
  id0:
    match: {    name: "ens*"   }
    addresses:
      - ${var.dns_server}/24
    gateway4: 192.168.3.1
    nameservers:
      search: [k8.local]
      addresses: [8.8.8.8]
  EOT
}