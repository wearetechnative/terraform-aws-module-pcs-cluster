resource "awscc_pcs_cluster" "this" {
  name = local.cluster_name

  networking = {
    subnet_ids         = var.networking.cluster_subnet_ids
    security_group_ids = var.networking.security_group_ids
  }

  scheduler = {
    type    = var.cluster.scheduler_type
    version = local.scheduler_version
  }

  size = local.cluster_size
}

resource "aws_launch_template" "this" {
  for_each = var.amis

  name        = "${local.cluster_name}-${each.key}"
  description = "AWS PCS ${each.key} nodes for ${local.cluster_name}"
  image_id    = each.value
  key_name    = var.key_name
  user_data   = base64encode(templatestring(var.bootstrap_scripts[each.key], local.bootstrap_context))

  vpc_security_group_ids = local.launch_template_settings[each.key].associate_public_ip_address ? null : var.networking.security_group_ids

  dynamic "network_interfaces" {
    for_each = local.launch_template_settings[each.key].associate_public_ip_address ? [1] : []

    content {
      associate_public_ip_address = true
      security_groups             = var.networking.security_group_ids
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = local.launch_template_settings[each.key].metadata_http_put_response_hop_limit
    http_tokens                 = local.launch_template_settings[each.key].metadata_http_tokens
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, local.launch_template_settings[each.key].tags, {
      Name = "${local.cluster_name}-${each.key}"
    })
  }

  tags = merge(var.tags, local.launch_template_settings[each.key].tags)
}

resource "awscc_pcs_compute_node_group" "this" {
  for_each = local.node_groups

  name       = each.value.name
  cluster_id = awscc_pcs_cluster.this.cluster_id

  custom_launch_template = {
    template_id = aws_launch_template.this[each.value.launch_template].id
    version     = aws_launch_template.this[each.value.launch_template].latest_version
  }

  iam_instance_profile_arn = var.iam_instance_profile_arn
  instance_configs = [{
    instance_type = each.value.instance_type
  }]

  scaling_configuration = {
    min_instance_count = each.value.min_instance_count
    max_instance_count = each.value.max_instance_count
  }

  subnet_ids = var.networking.node_group_subnet_ids[each.value.subnet_group]
  ami_id     = var.amis[each.value.launch_template]
}

resource "awscc_pcs_queue" "this" {
  for_each = local.queues

  name       = each.key
  cluster_id = awscc_pcs_cluster.this.cluster_id

  compute_node_group_configurations = [
    for node_group_key in each.value : {
      compute_node_group_id = awscc_pcs_compute_node_group.this[node_group_key].compute_node_group_id
    }
  ]
}
