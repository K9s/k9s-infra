locals {
  pve_vars    = read_terragrunt_config(find_in_parent_folders("pve.hcl"))
  global_vars = read_terragrunt_config(find_in_parent_folders("global.hcl"))
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "2.9.11"
    }
  }
}

provider "proxmox" {
  pm_tls_insecure = true
  pm_api_url      = "https://${local.pve_vars.locals.target_nodes[0]}.${local.pve_vars.locals.domain_name}:8006/api2/json"
  pm_parallel     = 20
  pm_timeout      = 600
}
EOF
}

remote_state {
  backend  = "local"
  config   = {
    path = "${get_parent_terragrunt_dir()}/../../../state/${path_relative_to_include()}/terraform.tfstate"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

inputs = merge(
  local.global_vars.locals,
  local.pve_vars.locals
)
