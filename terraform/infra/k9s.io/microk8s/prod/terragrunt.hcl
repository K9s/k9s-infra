include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "../../../..//ensembles/microk8s"
}

dependency "cloudimg" {
  config_path = "../../pve/cloudimg-template/ubuntu-jammy"
}

dependency "cloudinit" {
  config_path = "../../pve/cloudinit-vendor-template/ubuntu-microk8s"
}

inputs = {
  name = "prod-mk8s"

  clone                 = dependency.cloudimg.outputs.name
  vendor_storage_target = dependency.cloudinit.outputs.storage_target

  num_instances = 4

  storage_target = "ssd"
  storage_size   = "200G"

  memory  = 65536
  balloon = 16384
  cores   = 6
  sockets = 2

  use_pet_name = false

  network_bridge = "vmbr2"

  tags = [ "mk8s" ]
}
