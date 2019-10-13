resource "null_resource" "config_iso_creator" {

  provisioner "local-exec" {
    command = "rm ${pathexpand("~")}/k8-demo/config-iso/${var.name}_config_files.iso"
    on_failure = "continue"
  }

  provisioner "local-exec" {
    # create and iso image
    command = "genisoimage -output ${pathexpand("~")}/k8-demo/config-iso/${var.name}_config_files.iso -volid cidata -joliet -rock ${var.config_iso_folder}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "rm ${pathexpand("~")}/k8-demo/config-iso/${var.name}_config_files.iso"
    on_failure = "continue"
  }
}

resource "libvirt_cloudinit_disk" "cloud_init_seeder_iso" {
    name        = "${var.name}-seed.iso"
    pool        = "${var.storage_pool}"
    user_data   = "${var.user_data}"
    meta_data   = "${var.meta_data}"
    network_config = "${var.network_config}"
}

resource "libvirt_volume" "bootable_volume" {
  name   = "${var.name}-bootable-vol.img"
  pool   = "${var.storage_pool}"
  base_volume_id = "${var.os_image_vol_id}"
  size   = "${var.bootable_drive_size * 1024 * 1024 * 1024}"
}

resource "libvirt_volume" "secondary_volume" {
  name   = "${var.name}-secondary-vol.img"
  pool   = "${var.storage_pool}"
  size   = "${var.secondary_drive_size * 1024 * 1024 * 1024}"
}

# permission issue : https://github.com/dmacvicar/terraform-provider-libvirt/commit/22f096d9
resource "libvirt_domain" "vm" {
  depends_on = ["null_resource.config_iso_creator"]

  name   = "${var.name}"
  memory = "${var.ram}"
  vcpu   = "${var.cpus}"

  cloudinit = "${libvirt_cloudinit_disk.cloud_init_seeder_iso.id}"
  
  disk = [
    {
      volume_id = "${libvirt_volume.bootable_volume.id}"
    },
    {
      volume_id = "${libvirt_volume.secondary_volume.id}"
    },
    {
      file = "${pathexpand("~")}/k8-demo/config-iso/${var.name}_config_files.iso"

    }
  ]

  network_interface {
    bridge = "${var.network}"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}