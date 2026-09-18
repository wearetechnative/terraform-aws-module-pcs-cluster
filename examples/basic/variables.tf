variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "config" {
  type = any
}

variable "networking" {
  type = any
}

variable "instance_profile_name" {
  type = string
}

variable "security_group_name" {
  type = string
}

variable "ingress_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "aws_account_id" {
  description = "Account this example deploys into. Guards the provider against applying to the wrong account."
  type        = string
  default     = "000000000000"
}

variable "project" {
  description = "Value for the IaC_Project default tag."
  type        = string
  default     = "pcs-cluster-example"
}

variable "git_url" {
  description = "Value for the Git_URL default tag, pointing at the repository that owns this stack."
  type        = string
  default     = "https://github.com/wearetechnative/terraform-aws-module-pcs-cluster"
}
