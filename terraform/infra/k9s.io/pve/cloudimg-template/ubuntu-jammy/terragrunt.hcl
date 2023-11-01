include "root" {
  path = find_in_parent_folders()
  expose = true
}

terraform {
  source = "../../../../..//ensembles/pve-vm-template"
}

inputs = {
  cloudimg_url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"

  vm_id = 1022041
}
