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

  default = "nvme"
}

variable "target_nodes" {
  type = list(string)
}

variable "storage_size" {
  type = string

  default = "32G"
}

variable "skip_provisioning" {
  type = bool

  default = false
}

variable "ssh_keys" {
  type = list

  default = []
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

variable "sockets" {
  type = number

  default = 1
}

variable "use_pet_name" {
  type = bool

  default = true
}

variable "network_bridge" {
  type = string

  default = "vmbr0"
}

variable "addons" {
  type = map

  default = {}
}

variable "always_get_addons" {
  type = bool

  default = true
}

variable "tags" {
  type = list

  default = []
}
