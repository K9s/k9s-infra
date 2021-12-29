output "connection_details" {
  value = local.connection_details
}

output "name" {
  value = proxmox_vm_qemu.this.name
}
