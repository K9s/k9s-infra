locals {
  cloudimg = split(".", reverse(split("/", var.cloudimg_url))[0])[0]
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

  provisioner "remote-exec" {
    inline = [
      "curl -o '${local.cloudimg}.img' -z '${local.cloudimg}.img' ${var.cloudimg_url}",
      "qm create ${var.vm_id} --memory 512 --net0 virtio,bridge=vmbr0",
      "qm set ${var.vm_id} --name ${local.cloudimg}",
      "qm set ${var.vm_id} --delete scsi0",
      "qm set ${var.vm_id} --delete unused0",
      "qm importdisk ${var.vm_id} ${local.cloudimg}.img ${var.storage_target}",
      "qm set ${var.vm_id} --scsihw virtio-scsi-pci --scsi0 ${var.storage_target}:vm-${var.vm_id}-disk-0",
      "qm set ${var.vm_id} --ide2 local-lvm:cloudinit",
      "qm set ${var.vm_id} --boot c --bootdisk scsi0",
      "qm set ${var.vm_id} --serial0 socket --vga serial0",
      "qm set ${var.vm_id} --machine q35",
      "echo 'Manually convert the vm ${var.vm_id} to a template (sorry breaks with qm command)'"
    ]
  }
}
