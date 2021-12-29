resource "null_resource" "provision" {
  count = var.skip_provisioning == false ? 1 : 0

  connection {
    type = "ssh"
    user = element(module.vms.*.connection_details.user, count.index)
    host = element(module.vms.*.connection_details.ip, count.index)
    port = element(module.vms.*.connection_details.port, count.index)
  }

  triggers = {
    servers = jsonencode(var.servers)
    connect_version = var.connect_version
  }

  provisioner "file" {
    source = "BedrockConnect.sh"
    destination = "BedrockConnect.sh"
  }

  provisioner "file" {
    source = "BedrockConnect.service"
    destination = "BedrockConnect.service"
  }

  provisioner "file" {
    content = jsonencode(var.servers)
    destination = "bedrock_connect_servers.json"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt install -y openjdk-8-jre-headless",
      "sudo wget https://github.com/Pugmatt/BedrockConnect/releases/download/${var.connect_version}/BedrockConnect-1.0-SNAPSHOT.jar -O /usr/local/bin/BedrockConnect.jar",
      "sudo mv BedrockConnect.sh /usr/local/bin/BedrockConnect.sh",
      "sudo chmod +x /usr/local/bin/BedrockConnect.sh",
      "sudo mv bedrock_connect_servers.json /etc/bedrock_connect_servers.json",
      "sudo mv BedrockConnect.service /etc/systemd/system/BedrockConnect.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable BedrockConnect",
      "sudo systemctl restart BedrockConnect",
    ]
  }
}
