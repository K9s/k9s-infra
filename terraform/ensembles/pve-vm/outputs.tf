output "vm_connection_details" {
  value = module.vms.*.connection_details
}
