variable "tenancy_ocid" {
  description = "The OCID of the tenancy"
  type        = string
  default     = "ocid1.tenancy.oc1..aaaaaaaaerpfsav3vgybi7nylv2qojstwz6l4s275fxvczvwzspzvvrmt3rq"
}

variable "frankfurt_region" {
  description = "The OCI region for the Frankfurt instance"
  type        = string
  default     = "eu-frankfurt-1"
}

variable "frankfurt_availability_domain" {
  description = "The availability domain where the Frankfurt instance will be created"
  type        = string
  default     = "aGAO:EU-FRANKFURT-1-AD-3"
}

variable "marseille_region" {
  description = "The OCI region for the Marseille instance"
  type        = string
  default     = "eu-marseille-1"
}

variable "marseille_availability_domain" {
  description = "The availability domain for the Marseille instance"
  type        = string
  default     = "aGAO:EU-MARSEILLE-1-AD-1"
}
