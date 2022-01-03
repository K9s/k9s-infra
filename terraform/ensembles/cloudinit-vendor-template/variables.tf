variable "name" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "target_nodes" {
  type = list(string)
}

variable "template_storage_id" {
  type = string

  default = "local"
}
