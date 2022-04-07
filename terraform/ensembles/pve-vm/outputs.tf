output "vm_connection_details" {
  value = module.vms.*.connection_details
}

output "target_node" {
  value = module.vms.*.target_node
}
