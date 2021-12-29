variable "vm_id" {
  type = string

  default = ""
}

variable "domain_name" {
  type = string
}

variable "target_node" {
  type = string
}

variable "storage_target" {
  type = string

  default = "local-lvm"
}

variable "cloudimg_url" {
  type = string
}
