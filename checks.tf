check "cluster_required_values" {
  assert {
    condition = (
      local.cluster_name != "" &&
      local.scheduler_version != "" &&
      local.cluster_size != ""
    )
    error_message = "Cluster name, scheduler version, and size are required. Use either generic names or cluster_name, pcs_scheduler_version, and pcs_size."
  }
}

check "bootstrap_scripts" {
  assert {
    condition     = alltrue([for key in keys(var.amis) : contains(keys(var.bootstrap_scripts), key)])
    error_message = "Every AMI key must have a matching bootstrap_scripts entry."
  }
}

check "node_group_launch_templates" {
  assert {
    condition     = alltrue([for group in values(local.node_groups) : contains(keys(var.amis), group.launch_template)])
    error_message = "Every node group launch_template must identify an entry in amis."
  }
}

check "node_group_subnets" {
  assert {
    condition     = alltrue([for group in values(local.node_groups) : contains(keys(var.networking.node_group_subnet_ids), group.subnet_group)])
    error_message = "Every node group subnet_group must identify an entry in networking.node_group_subnet_ids."
  }
}

check "node_group_scaling" {
  assert {
    condition = alltrue([
      for group in values(local.node_groups) :
      group.min_instance_count >= 0 && group.max_instance_count >= group.min_instance_count
    ])
    error_message = "Every node group must have non-negative scaling limits and max_instance_count must be at least min_instance_count."
  }
}
