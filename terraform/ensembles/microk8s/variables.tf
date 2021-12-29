variable "name" {
  type = string
}

variable "num_instances" {
  type = number

  default = 1
}

variable "domain_name" {
  type = string
}

variable "clone" {
  type = string
}

variable "vendor_storage_target" {
  type = string

  default = ""
}

variable "storage_target" {
  type = string

  default = "local-lvm"
}

variable "target_node" {
  type = string
}

variable "skip_provisioning" {
  type = bool

  default = false
}

variable "addons" {
  type = map

  default = {}
}

variable "ssh_keys" {
  type = list

  default = []
}

variable "always_get_addons" {
  type = bool

  default = true
}

variable "memory" {
  type = number

  default = 8192
}

variable "cores" {
  type = number

  default = 6
}

variable "sockets" {
  type = number

  default = 1
}
