output "connection_details" {
  value = local.connection_details
}

output "name" {
  value = proxmox_vm_qemu.this.name
}

output "vmid" {
  value = local.qm_id
}

output "target_node" {
  value = var.target_node
}
