variable "project" {
  type        = string
  description = "GCP project id"
  default     = "serverledge-507513"
}

# Regione A (Edge) - Milano
variable "region_edge" {
  type    = string
  default = "europe-west8"
}
variable "zone_edge" {
  type    = string
  default = "europe-west8-a"
}

# Regione B (Cloud) - Stati Uniti
variable "region_cloud" {
  type    = string
  default = "us-east4"
}
variable "zone_cloud" {
  type    = string
  default = "us-east4-a"
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "image_x86" {
  type    = string
  default = "ubuntu-os-cloud/ubuntu-minimal-2404-lts-amd64"
}

# Dimensionamento risorse
variable "machine_type_edge" {
  default = "n2-standard-2" # 2 vCPU dedicate, 8GB RAM per l'Edge
}
variable "machine_type_cloud" {
  default = "n2-standard-4" # 4 vCPU dedicate, 16GB RAM per il Cloud
}
variable "machine_type_medium" {
  default = "e2-standard-2" # 2 vCPU, 8GB RAM
}
