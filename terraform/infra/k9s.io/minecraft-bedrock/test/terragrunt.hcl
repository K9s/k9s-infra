include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "../../../..//ensembles/pve-vm"
}

dependency "cloudimg" {
  config_path = "../../pve/cloudimg-template/ubuntu-lts"
}

dependency "cloudinit" {
  config_path = "../../pve/cloudinit-vendor-template/ubuntu-qemu-guest"
}

inputs = {
  name = "test"

  clone                 = dependency.cloudimg.outputs.name
  vendor_storage_target = dependency.cloudinit.outputs.storage_target

  memory = 2048
  num_instances = 6

  storage_target = "rbd"
}
