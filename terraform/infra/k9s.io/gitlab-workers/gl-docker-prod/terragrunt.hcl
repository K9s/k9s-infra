include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "../../../..//ensembles/pve-vm"
}

dependency "cloudimg" {
  config_path = "../../pve/cloudimg-template/ubuntu-jammy"
}

dependency "cloudinit" {
  config_path = "../../pve/cloudinit-vendor-template/gl-runner"
}

inputs = {
  name = "gl-docker-prod"

  clone                 = dependency.cloudimg.outputs.name
  vendor_storage_target = dependency.cloudinit.outputs.storage_target

  memory = 16384
  num_instances = 1

  storage_target = "nvme"

#  use_pet_name = true

  network_bridge = "vmbr2"
}
