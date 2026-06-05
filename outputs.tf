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
