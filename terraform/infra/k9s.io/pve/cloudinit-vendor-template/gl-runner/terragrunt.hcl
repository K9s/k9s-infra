include "root" {
  path = find_in_parent_folders()
  expose = true
}


terraform {
  source = "../../../../..//ensembles/cloudinit-vendor-template"
}

inputs = {
  name = "gl-runner"
}
