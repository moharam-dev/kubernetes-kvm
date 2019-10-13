data "template_file" "network_config" {
  template = <<EOT
# dhcp address

version: 2
ethernets:
  id0:
    match: {    name: "ens*"   }
    dhcp4: true
    nameservers:
      search: [k8.local]
      addresses: [${var.dns_server}]
  EOT
}