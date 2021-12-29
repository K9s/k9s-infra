module "vms" {
  source = "../../modules/pve-vm"

  count = var.num_instances

  vm_id = count.index + 1

  domain_name = var.domain_name

  name = "${var.name}-${random_pet.cluster.id}"

  clone = var.clone

  vendor_storage_target = var.vendor_storage_target
  storage_target        = var.storage_target

  target_node = var.target_node

  ssh_keys = var.ssh_keys

  storage_size = "200G"

  cores = var.cores
  sockets = var.sockets

  memory = var.memory
}

resource "random_pet" "cluster" {}
