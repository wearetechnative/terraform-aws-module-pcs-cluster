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
