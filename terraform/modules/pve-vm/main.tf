terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
    }
  }
}

locals {
  ssh_user = var.os_type == "ubuntu" ? "ubuntu" : "root"

  connection_details = {
    host = proxmox_vm_qemu.this.name
    user = local.ssh_user
    ip   = proxmox_vm_qemu.this.ssh_host
    port = proxmox_vm_qemu.this.ssh_port
    domain = var.domain_name
  }

  cicustom = var.vendor_storage_target == "" ? "" : "vendor=${var.vendor_storage_target}"
}

resource "proxmox_vm_qemu" "this" {
  lifecycle {
    ignore_changes = [disk]
  }

  name = "${var.name}${var.vm_id == "" ? "" : "-${var.vm_id}"}"

  # Cloud-Init Bits
  clone = var.clone

  cicustom                = local.cicustom
  cloudinit_cdrom_storage = "local-lvm"
  ipconfig0               = "ip=dhcp"
  sshkeys                 = join("\n", var.ssh_keys)
  searchdomain            = var.domain_name

  os_type = var.os_type
  onboot  = true

  # VM Options
  memory  = var.memory
  cores   = var.cores
  sockets = var.sockets

  # Hardware Options
  cpu    = "host"
  scsihw = "virtio-scsi-pci"

  # PVE Options
  target_node = var.target_node
  agent       = 1

  disk {
    type    = "scsi"
    storage = var.storage_target
    ssd     = 1
    size    = var.storage_size
    discard = "on"
  }

  network {
    bridge = var.network_bridge
    model  = "virtio"
  }

  vga {
    memory = 0
    type   = "serial0"
  }

  ssh_user = local.ssh_user

  connection {
    type        = "ssh"
    user        = self.ssh_user
    private_key = self.ssh_private_key
    host        = self.ssh_host
    port        = self.ssh_port
  }


  provisioner "remote-exec" {
    inline = [
      "until cloud-init status | grep done; do echo 'Waiting for cloudinit to complete' && sleep 5; done",
      "sudo reboot &"
    ]
  }

  provisioner "local-exec" {
    command = "echo 'Waiting 60s for node to reboot' && sleep 60"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Node Ready'"
    ]
  }
}
