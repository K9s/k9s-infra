locals {
  storage_paths = {
    "local"   = "/var/lib/vz/snippets/${var.name}.yml"
    "cephfs"  = "/mnt/pve/cephfs/snippets/${var.name}.yml"
  }

  storage_path    = local.storage_paths[var.template_storage_id]
  storage_target  = "${var.template_storage_id}:snippets/${var.name}.yml"
}

resource "null_resource" "create_template_vm" {
  count = length(var.target_nodes)

  connection {
    type        = "ssh"
    user        = "root"
    host        = "${element(var.target_nodes, count.index)}.${var.domain_name}"
    port        = 22
  }

  triggers = {
    always = timestamp()
  }

  provisioner "file" {
    source      = "cloudinit.yml"
    destination = local.storage_path
  }
}
