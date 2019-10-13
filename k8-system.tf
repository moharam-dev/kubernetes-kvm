
resource "libvirt_pool" "system_pool" {
  name = "k8-storage-pool"
  type = "dir"
  path = "${pathexpand("~")}/k8-demo/k8-storage-pool"
}

resource "libvirt_volume" "os_image_volume" {
  name   = "ubuntu-cloud-18.04-source.img"
  pool   = "${libvirt_pool.system_pool.name}"
  source = "${pathexpand("~")}/k8-demo/ubuntu-18.04-server-cloudimg-amd64.img"
  # source = "https://cloud-images.ubuntu.com/releases/bionic/release/ubuntu-18.04-server-cloudimg-amd64.img"
}

/*
# Commented till the know-how gained !
resource "libvirt_network" "system_network" {
  name = "host-bridge"
  mode = "bridge"
  bridge = "br0"
}
*/

module "dns_server" {
  source = "./modules/powerdns"

  name = "dns"

  cpus = "2"
  ram = "2048"
  storage_pool = "${libvirt_pool.system_pool.name}"
  network = "${var.bridge != "no" ? var.bridge : "default"}"
  dns_server = "${var.local_zone_dns}"
  common_password = "${var.common_password}"
  os_image_vol_id =  "${libvirt_volume.os_image_volume.id}"
}


module "etcd_server" {
  source = "./modules/etcd"

  name = "etcd1"

  cpus = "2"
  ram = "2048"
  storage_pool = "${libvirt_pool.system_pool.name}"
  network = "${var.bridge != "no" ? var.bridge : "default"}"
  dns_server = "${var.local_zone_dns}"
  common_password = "${var.common_password}"
  os_image_vol_id =  "${libvirt_volume.os_image_volume.id}"
}

module "linstor-storage" {
  source = "./modules/linstor-storage"

  name = "linstor"

  cpus = "2"
  ram = "2048"
  storage_pool = "${libvirt_pool.system_pool.name}"
  os_image_vol_id =  "${libvirt_volume.os_image_volume.id}"
  
  network = "${var.bridge != "no" ? var.bridge : "default"}"
  dns_server = "${var.local_zone_dns}"
  common_password = "${var.common_password}"
}

module "k8_master_server" {
  source = "./modules/k8-master"

  name = "master"

  cpus = "2"
  ram = "2048"
  storage_pool = "${libvirt_pool.system_pool.name}"
  network = "${var.bridge != "no" ? var.bridge : "default"}"
  dns_server = "${var.local_zone_dns}"
  common_password = "${var.common_password}"
  os_image_vol_id =  "${libvirt_volume.os_image_volume.id}"
}


module "k8_node" {
  source = "./modules/k8-node"

  name = "node1"

  cpus = "2"
  ram = "2048"
  storage_pool = "${libvirt_pool.system_pool.name}"
  network = "${var.bridge != "no" ? var.bridge : "default"}"
  dns_server = "${var.local_zone_dns}"
  common_password = "${var.common_password}"
  os_image_vol_id =  "${libvirt_volume.os_image_volume.id}"
}

