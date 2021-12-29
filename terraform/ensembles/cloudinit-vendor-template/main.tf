locals {
  storage_path = "/var/lib/vz/snippets/${var.name}.yml"
  storage_target = "local:snippets/${var.name}.yml"
}

resource "null_resource" "create_template_vm" {
  connection {
    type        = "ssh"
    user        = "root"
    host        = "${var.target_node}.${var.domain_name}"
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
