include "root" {
  path = find_in_parent_folders()
  expose = true
}

terraform {
  source = "../../../../..//ensembles/pve-vm-template"
}

inputs = {
  cloudimg_url = "https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"

  storage_target = "nvme"

  vm_id = 10000
}
