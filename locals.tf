locals {
  cluster_name      = coalesce(var.cluster.name, var.cluster.cluster_name, "")
  scheduler_version = coalesce(var.cluster.scheduler_version, var.cluster.pcs_scheduler_version, "")
  cluster_size      = coalesce(var.cluster.size, var.cluster.pcs_size, "")
  cluster_queues    = length(var.cluster.queues) > 0 ? var.cluster.queues : var.cluster.cluster_setup

  login_node = var.cluster.login_node != null ? var.cluster.login_node : (
    var.cluster.login_node_instance_type != null ? {
      enabled            = true
      name               = "login"
      instance_type      = var.cluster.login_node_instance_type
      launch_template    = "login"
      subnet_group       = "public"
      min_instance_count = 1
      max_instance_count = 1
    } : null
  )

  bootstrap_context = {
    template_efs_id                = try(var.filesystems.efs.id, "")
    template_efs_mount_point       = try(var.filesystems.efs.mount_point, "")
    template_lustre_id             = try(var.filesystems.lustre.id, "")
    template_lustre_dns            = try(var.filesystems.lustre.dns_name, "")
    template_lustre_mount_point    = try(var.filesystems.lustre.mount_name, "")
    template_lustre_local_path     = try(var.filesystems.lustre.mount_point, "")
    template_lustre_writable_paths = jsonencode(sort(tolist(try(var.filesystems.lustre.writable_paths, []))))
  }

  launch_template_settings = {
    for key in keys(var.amis) : key => {
      associate_public_ip_address          = try(var.launch_template_settings[key].associate_public_ip_address, key == "login")
      metadata_http_tokens                 = try(var.launch_template_settings[key].metadata_http_tokens, "required")
      metadata_http_put_response_hop_limit = try(var.launch_template_settings[key].metadata_http_put_response_hop_limit, 2)
      tags                                 = try(var.launch_template_settings[key].tags, {})
    }
  }

  queue_node_groups = {
    for item in flatten([
      for queue_name, groups in local.cluster_queues : [
        for group_name, group in groups : {
          key                = "${queue_name}:${group_name}"
          name               = group_name
          queue_name         = queue_name
          instance_type      = group.instance_type
          min_instance_count = group.min_instance_count
          max_instance_count = group.max_instance_count
          launch_template    = group.launch_template
          subnet_group       = group.subnet_group
        }
      ]
    ]) : item.key => item
  }

  login_node_groups = try(local.login_node.enabled, false) ? {
    login = {
      key                = "login"
      name               = local.login_node.name
      queue_name         = null
      instance_type      = local.login_node.instance_type
      min_instance_count = local.login_node.min_instance_count
      max_instance_count = local.login_node.max_instance_count
      launch_template    = local.login_node.launch_template
      subnet_group       = local.login_node.subnet_group
    }
  } : {}

  node_groups = merge(local.login_node_groups, local.queue_node_groups)

  queues = {
    for queue_name, groups in local.cluster_queues :
    queue_name => [for group_name in keys(groups) : "${queue_name}:${group_name}"]
  }
}
