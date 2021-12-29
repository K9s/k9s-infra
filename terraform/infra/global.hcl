locals {
  ssh_keys = [
    file(pathexpand("~/.ssh/id_rsa.pub"))
  ]
}
