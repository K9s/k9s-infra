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

dependency "k8s_cluster" {
  config_path = "../../microk8s/dev"
}

inputs = {
  name = "minecraft-bedrock-connect"

  clone                 = dependency.cloudimg.outputs.name
  vendor_storage_target = dependency.cloudinit.outputs.storage_target

  servers = [
    {
      "name" : "KennedyCraft - XMAS",
      "iconUrl" : "https://i.imgur.com/3BmFZRE.png",
      "address" : dependency.k8s_cluster.outputs.vm_connection_details.0.ip,
      "port" : 32285
    },{
      "name" : "KennedyCraft - GH",
      "iconUrl" : "https://i.imgur.com/3BmFZRE.png",
      "address" : dependency.k8s_cluster.outputs.vm_connection_details.0.ip,
      "port" : 30003
    }
  ]

  memory = 2048
  num_instances = 1
}
