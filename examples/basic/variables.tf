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

variable "tags" {
  type    = map(string)
  default = {}
}
