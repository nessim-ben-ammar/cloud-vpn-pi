# Infrastructure as Code (Terraform)

This directory provisions cloud VPN endpoints (WireGuard servers) and supporting network resources. Outputs from Terraform are consumed by the client utilities and deployment scripts.

## Files

- `provider.tf` / `backend.tf`: Provider configuration and remote state backend.
- `network.tf`: VPC/VNet, subnets, and security groups/firewall rules for WireGuard.
- `compute.tf`: Virtual machine definition (includes user data for WireGuard setup).
- `user-data.yaml`: Cloud-init template that installs WireGuard, configures the server, and exposes a management user.
- `variables.tf` / `terraform.tfvars` (user-created): Input variables for regions, instance sizes, SSH keys, and endpoints.
- `outputs.tf`: Values consumed by the `clients/` scripts (public IPs, VPN endpoints, SSH connection info).

## Usage

1. Configure your provider credentials (see `provider.tf`) and create a `terraform.tfvars` file that sets region, SSH key paths, and any per-location variables referenced in `variables.tf`.
2. Initialize the workspace:
   ```bash
   terraform init
   ```
3. Review and apply changes:
   ```bash
   terraform plan
   terraform apply
   ```
4. After apply, use the outputs to generate client configs or connect to instances (the `clients/add_client.sh` script reads these outputs automatically).

## Cleanup

Destroy the provisioned infrastructure when finished:
```bash
terraform destroy
```
