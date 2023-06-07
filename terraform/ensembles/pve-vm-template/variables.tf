variable "vm_id" {
  type = number
}

variable "domain_name" {
  type = string
}

variable "target_nodes" {
  type = list(string)
}

variable "storage_target" {
  type = string

  default = "rbd"
}

variable "cloudimg_url" {
  type = string
}
