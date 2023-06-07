variable "name" {
  type = string
}

variable "vm_id" {
  type = string

  default = ""
}

variable "tags" {
  type = list

  default = []
}

variable "clone" {
  type = string
}

variable "target_node" {
  type = string
}

variable "storage_target" {
  type = string

  default = "local-lvm"
}

variable "storage_size" {
  type = string

  default = "32G"
}

variable "memory" {
  type = number

  default = 8192
}

variable "balloon" {
  type = number

  default = 0
}


variable "cores" {
  type = number

  default = 6
}

variable "numa" {
  type = bool

  default = true
}

variable "sockets" {
  type = number

  default = 1
}

variable "os_type" {
  type = string

  default = "ubuntu"
}

variable "domain_name" {
  type = string
}

variable "vendor_storage_target" {
  type = string

  default = ""
}

variable "ssh_keys" {
  type = list

  default = []
}

variable "network_bridge" {
  type = string

  default = "vmbr0"
}
