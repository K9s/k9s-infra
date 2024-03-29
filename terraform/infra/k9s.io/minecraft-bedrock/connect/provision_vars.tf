variable "servers" {
  type = list(object({ name = string, iconUrl = string, address = string, port = number }))

  default = []
}

variable "connect_version" {
  type = string

  default = "1.26"
}
