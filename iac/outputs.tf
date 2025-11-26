# Output the public IP
output "instance_public_ips" {
  description = "Public IP addresses of the cloud VPN instances"
  value = {
    (var.frankfurt_region) = oci_core_instance.cloud_vpn_instance_frankfurt.public_ip
    (var.marseille_region) = oci_core_instance.cloud_vpn_instance_marseille.public_ip
  }
}

# Output SSH connection commands
output "ssh_connection_commands" {
  description = "Commands to connect to the instances via SSH"
  value = {
    (var.frankfurt_region) = "ssh -i ${local_file.ssh_private_key.filename} ubuntu@${oci_core_instance.cloud_vpn_instance_frankfurt.public_ip}"
    (var.marseille_region) = "ssh -i ${local_file.ssh_private_key.filename} ubuntu@${oci_core_instance.cloud_vpn_instance_marseille.public_ip}"
  }
}

output "vpn_endpoints" {
  description = "DNS names or IPs clients should connect to"
  value = {
    (var.frankfurt_region) = oci_core_instance.cloud_vpn_instance_frankfurt.public_ip
    (var.marseille_region) = oci_core_instance.cloud_vpn_instance_marseille.public_ip
  }
}
