variable "name_prefix" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}

# Network
variable "vpc_id" { type = string }

variable "public_subnet_id" { type = string }

variable "private_subnet_ids" { type = list(string) }
variable "allowed_cidrs" {
  type    = list(string)
  default = []
}
variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = []
}

# Logging / KMS
variable "enable_cloudwatch_logs" {
  type    = bool
  default = true
}
variable "enable_s3_logs" {
  type    = bool
  default = true
}
variable "create_kms_key" {
  type    = bool
  default = true
}
variable "log_retention_days" {
  type    = number
  default = 90
}

# VPC Endpoints
variable "create_vpc_endpoints" {
  type    = bool
  default = true
}

# Bastion specifics
variable "ami_id" { type = string }
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "enable_public_ip" {
  type    = bool
  default = false
}
variable "enable_ssh_fallback" {
  type    = bool
  default = false
}
variable "attach_admin_policy" {
  type    = bool
  default = true
}