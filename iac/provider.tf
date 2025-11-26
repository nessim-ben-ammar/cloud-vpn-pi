provider "oci" {
  region = var.frankfurt_region
}

provider "oci" {
  alias  = "marseille"
  region = var.marseille_region
}
