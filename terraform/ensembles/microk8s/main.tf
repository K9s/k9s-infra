module "vms" {
  source = "../../modules/pve-vm"

  tags = var.tags

  count = var.num_instances

  vm_id = count.index + 1

  domain_name = var.domain_name

  name = var.use_pet_name ? "${var.name}-${random_pet.cluster.id}" : var.name

  clone = var.clone

  vendor_storage_target = var.vendor_storage_target

  storage_target = var.storage_target
  storage_size   = var.storage_size

  target_node = element(var.target_nodes, count.index)

  ssh_keys = var.ssh_keys

  cores   = var.cores
  sockets = var.sockets

  memory  = var.memory
  balloon = var.balloon

  network_bridge = var.network_bridge
}

resource "random_pet" "cluster" {}
