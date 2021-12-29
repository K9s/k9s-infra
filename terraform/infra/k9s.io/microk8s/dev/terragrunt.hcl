include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "../../../..//ensembles/microk8s"
}

dependency "cloudimg" {
  config_path = "../../pve/cloudimg-template/ubuntu-lts"
}

dependency "cloudinit" {
  config_path = "../../pve/cloudinit-vendor-template/ubuntu-microk8s"
}

inputs = {
  name = "dev-mk8s"

  clone                 = dependency.cloudimg.outputs.name
  vendor_storage_target = dependency.cloudinit.outputs.storage_target

  num_instances = 5

  storage_target = "nvme"

  memory  = 16384
  cores   = 8
  sockets = 2
}
