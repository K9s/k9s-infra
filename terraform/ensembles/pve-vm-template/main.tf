locals {
  cloudimg = split(".", reverse(split("/", var.cloudimg_url))[0])[0]
}

resource "null_resource" "create_template_vm" {
  count = length(var.target_nodes)

  connection {
    type        = "ssh"
    user        = "root"
    host        = "${var.target_nodes[count.index]}.${var.domain_name}"
    port        = 22
  }

  triggers = {
    always = timestamp()
  }

  provisioner "remote-exec" {
    inline = [
      "curl -o '${local.cloudimg}.img' -z '${local.cloudimg}.img' ${var.cloudimg_url}",
      "qm create ${var.vm_id + count.index} --memory 512 --net0 virtio,bridge=vmbr0",
      "qm set ${var.vm_id + count.index} --name ${local.cloudimg}",
      "qm set ${var.vm_id + count.index} --delete scsi0",
      "qm set ${var.vm_id + count.index} --delete unused0",
      "qm importdisk ${var.vm_id + count.index} ${local.cloudimg}.img ${var.storage_target}",
      "qm set ${var.vm_id + count.index} --scsihw virtio-scsi-pci --scsi0 ${var.storage_target}:vm-${var.vm_id + count.index}-disk-0",
      "qm set ${var.vm_id + count.index} --ide2 nvme:cloudinit",
      "qm set ${var.vm_id + count.index} --boot c --bootdisk scsi0",
      "qm set ${var.vm_id + count.index} --serial0 socket --vga serial0",
      "qm set ${var.vm_id + count.index} --machine q35",
      "echo 'Manually convert the vm ${var.vm_id + count.index} to a template (sorry breaks with qm command)'"
    ]
  }
}
