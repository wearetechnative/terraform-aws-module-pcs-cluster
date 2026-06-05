variable "cluster" {
  description = "PCS cluster and nested queue/node-group definition."
  type = object({
    name                  = optional(string)
    cluster_name          = optional(string)
    scheduler_type        = optional(string, "SLURM")
    scheduler_version     = optional(string)
    pcs_scheduler_version = optional(string)
    size                  = optional(string)
    pcs_size              = optional(string)
    login_node = optional(object({
      enabled            = optional(bool, true)
      name               = optional(string, "login")
      instance_type      = string
      launch_template    = optional(string, "login")
      subnet_group       = optional(string, "public")
      min_instance_count = optional(number, 1)
      max_instance_count = optional(number, 1)
    }))
    login_node_instance_type = optional(string)
    queues = optional(map(map(object({
      instance_type      = string
      min_instance_count = number
      max_instance_count = number
      launch_template    = optional(string, "compute")
      subnet_group       = optional(string, "private")
    }))), {})
    cluster_setup = optional(map(map(object({
      instance_type      = string
      min_instance_count = number
      max_instance_count = number
      launch_template    = optional(string, "compute")
      subnet_group       = optional(string, "private")
    }))), {})
  })
}

variable "amis" {
  description = "AMI IDs keyed by launch-template type, for example compute, login, and dcv."
  type        = map(string)
}

variable "bootstrap_scripts" {
  description = "Bootstrap template content keyed like amis. Filesystem values are rendered into each template."
  type        = map(string)
}

variable "filesystems" {
  description = "Optional existing EFS and FSx for Lustre filesystems exposed to bootstrap templates."
  type = object({
    efs = optional(object({
      id          = string
      mount_point = optional(string, "/home")
    }))
    lustre = optional(object({
      id             = optional(string)
      dns_name       = string
      mount_name     = string
      mount_point    = optional(string, "/fsx")
      writable_paths = optional(set(string), [])
    }))
  })
  default = {}
}

variable "networking" {
  description = "Existing networking used by the PCS cluster and its node groups."
  type = object({
    cluster_subnet_ids    = list(string)
    security_group_ids    = list(string)
    node_group_subnet_ids = map(list(string))
  })

  validation {
    condition = (
      length(var.networking.cluster_subnet_ids) > 0 &&
      length(var.networking.security_group_ids) > 0 &&
      alltrue([for subnet_ids in values(var.networking.node_group_subnet_ids) : length(subnet_ids) > 0])
    )
    error_message = "Cluster subnet IDs, security group IDs, and every node-group subnet group must be non-empty."
  }
}

variable "iam_instance_profile_arn" {
  description = "IAM instance profile ARN used by all PCS compute node groups."
  type        = string
}

variable "key_name" {
  description = "Optional EC2 key pair name added to all launch templates."
  type        = string
  default     = null
}

variable "launch_template_settings" {
  description = "Optional settings per generated launch-template type."
  type = map(object({
    associate_public_ip_address          = optional(bool, false)
    metadata_http_tokens                 = optional(string, "required")
    metadata_http_put_response_hop_limit = optional(number, 2)
    tags                                 = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to all managed launch templates and instances."
  type        = map(string)
  default     = {}
}
