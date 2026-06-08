resource "awscc_pcs_cluster" "this" {
  name = var.cluster_name

  networking = {
    subnet_ids         = var.networking.cluster_subnet_ids
    security_group_ids = local.security_group_ids
  }

  scheduler = {
    type    = "SLURM"
    version = var.config.pcs_scheduler_version
  }

  size = var.config.pcs_size
}

resource "aws_launch_template" "this" {
  for_each = local.launch_templates

  name        = "${var.cluster_name}-${each.key}"
  description = "AWS PCS ${each.key} nodes for ${var.cluster_name}"
  image_id    = each.value.image_id
  key_name    = var.config.template_keypair_name
  user_data   = base64encode(templatefile(each.value.template_path, local.bootstrap_context))

  vpc_security_group_ids = each.value.associate_public_ip_address ? null : local.security_group_ids

  dynamic "network_interfaces" {
    for_each = each.value.associate_public_ip_address ? [1] : []

    content {
      associate_public_ip_address = true
      security_groups             = local.security_group_ids
    }
  }

  dynamic "iam_instance_profile" {
    for_each = each.value.include_instance_profile ? [1] : []

    content {
      arn = local.instance_profile_arn
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.cluster_name}-${each.key}"
    })
  }

  tags = var.tags
}

resource "awscc_pcs_compute_node_group" "this" {
  for_each = local.node_groups

  name       = each.value.name
  cluster_id = awscc_pcs_cluster.this.cluster_id

  custom_launch_template = {
    template_id = aws_launch_template.this[each.value.launch_template].id
    version     = aws_launch_template.this[each.value.launch_template].latest_version
  }

  iam_instance_profile_arn = local.instance_profile_arn
  instance_configs = [{
    instance_type = each.value.instance_type
  }]

  scaling_configuration = {
    min_instance_count = each.value.min_instance_count
    max_instance_count = each.value.max_instance_count
  }

  subnet_ids = each.value.subnet_ids
  ami_id     = local.launch_templates[each.value.launch_template].image_id
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
