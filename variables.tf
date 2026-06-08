variable "cluster_name" {
  description = "Name of the PCS cluster."
  type        = string
}

variable "config" {
  description = "PCS cluster configuration matching the project tfvars shape."
  type = object({
    template_efs_id                = optional(string, "")
    template_lustre_id             = optional(string, "")
    template_lustre_dns            = optional(string, "")
    template_lustre_mount_point    = optional(string, "")
    template_lustre_writable_paths = optional(set(string), [])

    template_keypair_name     = optional(string)
    template_image_id_compute = string
    template_image_id_login   = string
    template_image_id_dcv     = string

    login_node_instance_type = string
    pcs_scheduler_version    = string
    pcs_size                 = string

    cluster_setup = map(map(object({
      instance_type      = string
      min_instance_count = number
      max_instance_count = number
      launch_template    = optional(string, "compute")
    })))
  })
}

variable "networking" {
  description = "Existing VPC and subnets used by the PCS cluster and nodes."
  type = object({
    vpc_id                   = string
    cluster_subnet_ids       = list(string)
    public_subnet_ids        = list(string)
    private_subnet_ids       = list(string)
    interactive_nodes_public = optional(bool, true)
  })

  validation {
    condition = (
      var.networking.vpc_id != "" &&
      length(var.networking.cluster_subnet_ids) > 0 &&
      length(var.networking.public_subnet_ids) > 0 &&
      length(var.networking.private_subnet_ids) > 0
    )
    error_message = "VPC ID plus cluster, public, and private subnet IDs must be non-empty."
  }
}

variable "security_group_name" {
  description = "Optional name for the module-created PCS node security group."
  type        = string
  default     = null
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach login/API ports on the module-created PCS security group."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags applied to all managed launch templates and instances."
  type        = map(string)
  default     = {}
}

variable "iam_instance_profile_arn" {
  description = "Optional existing IAM instance profile ARN. When null, the module creates the PCS role and instance profile."
  type        = string
  default     = null
}

variable "instance_profile_name" {
  description = "Name suffix for the module-created PCS IAM role and instance profile. The module adds the required AWSPCS prefixes."
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN to grant decrypt and data-key permissions to the module-created PCS role."
  type        = string
  default     = null
}

variable "additional_policy_jsons" {
  description = "Additional IAM policy JSON documents attached to the module-created PCS role for project-specific access."
  type        = list(string)
  default     = []
}
