module "vms" {
  source = "../../modules/pve-vm"

  count = var.num_instances

  vm_id = count.index + 1

  domain_name = var.domain_name

  name = var.use_pet_name ? "${var.name}-${random_pet.cluster.id}" : var.name

  clone = var.clone

  vendor_storage_target = var.vendor_storage_target

  target_node = var.target_node

  ssh_keys = var.ssh_keys

  cores = var.cores
  sockets = var.sockets

  memory = var.memory

  network_bridge = var.network_bridge
}

resource "random_pet" "cluster" {}
