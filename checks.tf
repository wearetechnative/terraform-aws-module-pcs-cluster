check "node_group_launch_templates" {
  assert {
    condition     = alltrue([for group in values(local.node_groups) : contains(keys(local.launch_templates), group.launch_template)])
    error_message = "Every cluster_setup node group launch_template must be one of: compute, login, dcv."
  }
}

check "node_group_scaling" {
  assert {
    condition = alltrue([
      for group in values(local.queue_node_groups) :
      group.min_instance_count >= 0 && group.max_instance_count >= group.min_instance_count
    ])
    error_message = "Every cluster_setup node group must have non-negative scaling limits and max_instance_count must be at least min_instance_count."
  }
}
