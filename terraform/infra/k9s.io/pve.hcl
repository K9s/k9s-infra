locals {
  domain_name = "or.k9s.io"

  target_nodes = [
    "pve1",
    "pve2",
    "pve3"
  ]

  template_storage_id = "cephfs"
}
