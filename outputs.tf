output "cluster_id" {
  description = "ID of the PCS cluster."
  value       = awscc_pcs_cluster.this.cluster_id
}

output "bootstrap_context" {
  description = "Filesystem context rendered into the bootstrap templates."
  value       = local.bootstrap_context
}

output "cluster" {
  description = "PCS cluster resource."
  value       = awscc_pcs_cluster.this
}

output "launch_templates" {
  description = "Managed launch templates keyed by their stable identifiers."
  value       = aws_launch_template.this
}

output "launch_template_ids" {
  description = "Launch template IDs keyed by their stable identifiers."
  value = {
    for key, template in aws_launch_template.this :
    key => template.id
  }
}

output "compute_node_group_ids" {
  description = "Compute node group IDs keyed by their stable Terraform identifiers."
  value = {
    for key, group in awscc_pcs_compute_node_group.this :
    key => group.compute_node_group_id
  }
}

output "queue_ids" {
  description = "Queue IDs keyed by their stable Terraform identifiers."
  value = {
    for key, queue in awscc_pcs_queue.this :
    key => queue.queue_id
  }
}

output "iam_instance_profile_arn" {
  description = "IAM instance profile ARN used by the PCS node groups."
  value       = local.instance_profile_arn
}

output "iam_role_arn" {
  description = "ARN of the module-created PCS IAM role, or null when an existing profile is supplied."
  value       = local.create_instance_profile ? aws_iam_role.pcs[0].arn : null
}

output "security_group_ids" {
  description = "Security group IDs used by the PCS cluster and nodes."
  value       = local.security_group_ids
}
