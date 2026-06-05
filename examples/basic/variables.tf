variable "aws_region" {
  type = string
}

variable "cluster" {
  type = any
}

variable "amis" {
  type = map(string)
}

variable "bootstrap_scripts" {
  type = map(string)
}

variable "filesystems" {
  type    = any
  default = {}
}

variable "networking" {
  type = any
}

variable "iam_instance_profile_arn" {
  type = string
}

variable "key_name" {
  type    = string
  default = null
}

variable "launch_template_settings" {
  type    = any
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
