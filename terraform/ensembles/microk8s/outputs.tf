output "vm_connection_details" {
  value = module.vms.*.connection_details
}

output "disabled_addons" {
  value = matchkeys(keys(local.addons_post), values(local.addons).*.status, ["disabled"])
}

output "enabled_addons" {
  value = matchkeys(keys(local.addons_post), values(local.addons).*.status, ["enabled"])
}

output "skip_provisioning" {
  value = var.skip_provisioning
}
