locals {
  ssh_base = "ssh -o 'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' ${module.vms.0.connection_details.user}@${module.vms.0.connection_details.ip}"

  _addons_post = lookup(yamldecode(module.get_addons_post.*.stdout[0]), "addons")
  addons_post  = zipmap(local._addons_post.*.name, local._addons)

  default_addons = {
    metrics-server = {
      "status" = "enabled"
    },
    dns            = {
      "status" = "enabled"
    },
    rbac            = {
      "status" = "enabled"
    }
  }

  _addons = lookup(yamldecode(module.get_addons.*.stdout[0]), "addons")
  addons  = zipmap(local._addons.*.name, local._addons)

  microk8s_up_cmd = "until sudo microk8s status | grep 'microk8s is running'; do echo 'Waiting for microk8s to be Ready' && sleep 5; done"
}

module "get_join_token" {
  count = var.skip_provisioning == false ? 1 : 0

  source = "matti/resource/shell"

  triggers = {
    nodes = join(",", module.vms.*.name)
  }

  command = "${local.ssh_base} 'sudo microk8s add-node -l 1200'"
}

resource "null_resource" "join_cluster" {
  count = var.skip_provisioning == false ? var.num_instances - 1 : 0

  connection {
    type = "ssh"
    user = element(module.vms.*.connection_details.user, count.index + 1)
    host = element(module.vms.*.connection_details.ip, count.index + 1)
    port = element(module.vms.*.connection_details.port, count.index + 1)
  }

  provisioner "remote-exec" {
    inline = [
      "${split("\n", "${join("", module.get_join_token.*.stdout)}\n")[1]} || true"
    ]
  }
}

#resource "null_resource" "set_hosts" {
#  count = var.skip_provisioning == false ? var.num_instances : 0
#
#  connection {
#    type = "ssh"
#    user = element(module.vms.*.connection_details.user, count.index)
#    host = element(module.vms.*.connection_details.ip, count.index)
#    port = element(module.vms.*.connection_details.port, count.index)
#  }
#
#  triggers = {
#    always = timestamp()
#  }
#
#  provisioner "remote-exec" {
#    inline = [
#      "echo '${join("\n", formatlist("%v %v", module.vms.*.connection_details.ip, module.vms.*.name))}' | awk 'BEGIN{ print \"\\n\\n# START NODE MEMBERS:\" }; { print $0 }; END{ print \"# END NODE MEMBERS\"}' | sudo tee -a /etc/hosts > /dev/null"
#    ]
#  }
#}

resource "null_resource" "validate_nodes" {
  depends_on = [null_resource.join_cluster]

  triggers = {
    nodes = join(",", module.vms.*.name)
  }

  connection {
    type = "ssh"
    user = module.vms.0.connection_details.user
    host = module.vms.0.connection_details.ip
    port = module.vms.0.connection_details.port
  }

  provisioner "remote-exec" {
    inline = [
      "echo '${var.skip_provisioning == false ? join("\n", sort(module.vms.*.name)) : module.vms.0.name}' > nodes",
      "until kubectl get nodes | grep Ready | cut -d ' ' -f 1 | sort | diff nodes -; do echo 'Waiting for k8s nodes to be Ready' && sleep 5; done",
      local.microk8s_up_cmd,
      "echo 'All nodes joined and in a ready state'"
    ]
  }
}

module "get_kubectl_config" {
  depends_on = [null_resource.validate_nodes]

  count = var.skip_provisioning == false ? 1 : 0

  source = "matti/resource/shell"

  command = "${local.ssh_base} 'sudo microk8s config'"
}

resource "local_sensitive_file" "kubectl_config" {
  content = concat(module.get_kubectl_config.*.stdout, [""])[0]

  file_permission = "0600"

  filename = pathexpand("~/.kube/${var.name}_config.yml")
}

resource "null_resource" "distribute_kubectl_config" {
  depends_on = [local_sensitive_file.kubectl_config]

  count = var.skip_provisioning == false ? var.num_instances - 1 : 0

  connection {
    type = "ssh"
    user = element(module.vms.*.connection_details.user, count.index + 1)
    host = element(module.vms.*.connection_details.ip, count.index + 1)
    port = element(module.vms.*.connection_details.port, count.index + 1)
  }

  provisioner "file" {
    source      = "~/.kube/${var.name}_config.yml"
    destination = "/var/snap/microk8s/current/credentials/client.config"
  }
}

module "get_addons" {
  depends_on = [null_resource.validate_nodes]

  source = "matti/resource/shell"

  triggers = {
    addons = jsonencode(var.addons)
  }

  command = "${local.ssh_base} 'sudo microk8s status --format yaml'"
}

resource "null_resource" "process_addons" {
  for_each = var.skip_provisioning == false ? merge(local.default_addons, var.addons) : {}

  depends_on = [module.get_addons]

  triggers = {
    addons = jsonencode(var.addons)
  }

  connection {
    type = "ssh"
    user = module.vms.0.connection_details.user
    host = module.vms.0.connection_details.ip
    port = module.vms.0.connection_details.port
  }

  provisioner "remote-exec" {

    inline = [
      "#!/bin/bash",
      "exec 100>/var/tmp/microk8s_addon.lock || exit 1",
      "flock 100 || exit 1",
      local.microk8s_up_cmd,
      "sudo microk8s ${merge(local.addons[each.key], each.value)["status"] == "enabled" ? "enable" : "disable"} ${each.key}"
    ]
  }
}

module "get_addons_post" {
  depends_on = [null_resource.process_addons]

  source = "matti/resource/shell"

  triggers = {
    addons = jsonencode(var.addons)
    always = var.always_get_addons ? timestamp() : false
  }

  command = "${local.ssh_base} 'sudo microk8s status --format yaml'"
}
