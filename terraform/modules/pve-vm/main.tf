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

  qm_id = element(split("/", proxmox_vm_qemu.this.id), 2)
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
  balloon = var.balloon

  cores   = var.cores
  numa = var.numa
  sockets = var.sockets

  # Hardware Options
  cpu    = "host"
  scsihw = "virtio-scsi-single"

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

  tags = join(",", var.tags)

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
      "until cloud-init status | grep done; do echo 'Waiting for cloudinit to complete' && sleep 5; done"
    ]
  }
}

resource "null_resource" "qm_restart_vm" {
  depends_on = [proxmox_vm_qemu.this]

  connection {
    type        = "ssh"
    user        = "root"
    host        = "${var.target_node}.${var.domain_name}"
    port        = 22
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Shutdown QM Node ${local.qm_id}' && qm shutdown ${local.qm_id} --forceStop 1 --timeout 120",
      "sleep 5",
      "echo 'Starting QM Node ${local.qm_id}' && qm start ${local.qm_id} --timeout 120",
      "sleep 5",
      "until qm guest cmd ${local.qm_id} get-host-name; do echo 'Waiting for QEMU guest agent to start' && sleep 5; done",
      "echo 'Node Ready'"
    ]
  }
}
