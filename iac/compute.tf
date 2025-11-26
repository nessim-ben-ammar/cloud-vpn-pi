# Data sources to get the latest Ubuntu 24.04 Minimal images per shape
locals {
  frankfurt_shape           = "VM.Standard.E2.1.Micro"
  marseille_shape           = "VM.Standard.A1.Flex"
  marseille_shape_memory_gb = 6
  marseille_shape_ocus      = 1
}

data "oci_core_images" "ubuntu_images_frankfurt" {
  compartment_id           = oci_identity_compartment.cloud_vpn_cmp.id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = local.frankfurt_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_core_images" "ubuntu_images_marseille" {
  provider                 = oci.marseille
  compartment_id           = oci_identity_compartment.cloud_vpn_cmp.id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = local.marseille_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Data source to get availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = oci_identity_compartment.cloud_vpn_cmp.id
}

# Generate SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the private key locally
resource "local_file" "ssh_private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/ssh_keys/oci-instance-ssh-key"
  file_permission = "0600"
}

# Save the public key locally
resource "local_file" "ssh_public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "${path.module}/ssh_keys/oci-instance-ssh-key.pub"
}

# Read existing SSH public key
locals {
  ssh_public_key = tls_private_key.ssh_key.public_key_openssh
}

# Create the compute instance
resource "oci_core_instance" "cloud_vpn_instance" {
  availability_domain = var.frankfurt_availability_domain
  compartment_id      = oci_identity_compartment.cloud_vpn_cmp.id
  display_name        = "cloud-vpn-${var.frankfurt_region}-instance"
  shape               = local.frankfurt_shape

  create_vnic_details {
    subnet_id        = oci_core_subnet.cloud_vpn_pub_sn.id
    assign_public_ip = true
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_images_frankfurt.images[0].id
    boot_volume_size_in_gbs = 50
  }

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
    user_data           = base64encode(file("${path.module}/user-data.yaml"))
  }

  preserve_boot_volume = false
}

resource "oci_core_instance" "cloud_vpn_instance_marseille" {
  provider            = oci.marseille
  availability_domain = var.marseille_availability_domain
  compartment_id      = oci_identity_compartment.cloud_vpn_cmp.id
  display_name        = "cloud-vpn-${var.marseille_region}-instance"
  shape               = local.marseille_shape

  shape_config {
    memory_in_gbs = local.marseille_shape_memory_gb
    ocpus         = local.marseille_shape_ocus
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.cloud_vpn_pub_sn_marseille.id
    assign_public_ip = true
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_images_marseille.images[0].id
    boot_volume_size_in_gbs = 50
  }

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
    user_data           = base64encode(file("${path.module}/user-data.yaml"))
  }

  preserve_boot_volume = false
}
