locals {
  create_instance_profile = var.iam_instance_profile_arn == null
  instance_profile_name   = coalesce(var.instance_profile_name, var.cluster_name)
  instance_profile_arn    = local.create_instance_profile ? aws_iam_instance_profile.pcs[0].arn : var.iam_instance_profile_arn
  security_group_ids      = [aws_security_group.pcs_nodes.id]
  interactive_subnet_ids  = var.networking.interactive_nodes_public ? var.networking.public_subnet_ids : var.networking.private_subnet_ids

  bootstrap_context = {
    template_efs_id                = var.config.template_efs_id
    template_lustre_id             = var.config.template_lustre_id
    template_lustre_dns            = var.config.template_lustre_dns
    template_lustre_mount_point    = var.config.template_lustre_mount_point
    template_lustre_writable_paths = jsonencode(sort(tolist(var.config.template_lustre_writable_paths)))
  }

  launch_templates = {
    compute = {
      image_id                    = var.config.template_image_id_compute
      template_path               = "${path.module}/templates/bootstrap-computenodes.init.tftpl"
      associate_public_ip_address = false
      include_instance_profile    = false
    }
    login = {
      image_id                    = var.config.template_image_id_login
      template_path               = "${path.module}/templates/bootstrap-loginnode.init.tftpl"
      associate_public_ip_address = var.networking.interactive_nodes_public
      include_instance_profile    = false
    }
    dcv = {
      image_id                    = var.config.template_image_id_dcv
      template_path               = "${path.module}/templates/bootstrap-dcvnodes.init.tftpl"
      associate_public_ip_address = var.networking.interactive_nodes_public
      include_instance_profile    = true
    }
  }

  queue_node_groups = {
    for item in flatten([
      for queue_name, groups in var.config.cluster_setup : [
        for group_name, group in groups : {
          key                = "${queue_name}:${group_name}"
          name               = group_name
          queue_name         = queue_name
          instance_type      = group.instance_type
          min_instance_count = group.min_instance_count
          max_instance_count = group.max_instance_count
          launch_template    = group.launch_template
          subnet_ids         = group.launch_template == "dcv" ? local.interactive_subnet_ids : var.networking.private_subnet_ids
        }
      ]
    ]) : item.key => item
  }

  login_node_group = {
    login = {
      key                = "login"
      name               = "login"
      queue_name         = null
      instance_type      = var.config.login_node_instance_type
      min_instance_count = 1
      max_instance_count = 1
      launch_template    = "login"
      subnet_ids         = local.interactive_subnet_ids
    }
  }

  node_groups = merge(local.login_node_group, local.queue_node_groups)

  queues = {
    for queue_name, groups in var.config.cluster_setup :
    queue_name => [for group_name in keys(groups) : "${queue_name}:${group_name}"]
  }
}
