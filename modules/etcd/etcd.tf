

module "etcd_server_vm" {
  source = "../kvm"

  name = "${var.name}"

  cpus = "${var.cpus}"
  ram = "${var.ram}"
  storage_pool = "${var.storage_pool}"
  network = "${var.network}"

  os_image_vol_id = "${var.os_image_vol_id}"
  bootable_drive_size = 10 # GB
  secondary_drive_size = 1 # GB

  meta_data = "${data.template_file.meta_data.rendered}"
  user_data = "${data.template_file.user_data.rendered}" 
  network_config = "${data.template_file.network_config.rendered}" 
  config_iso_folder = "${path.module}/config-files"
}