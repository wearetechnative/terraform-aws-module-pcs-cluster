resource "aws_security_group" "pcs_nodes" {
  name        = coalesce(var.security_group_name, "${var.cluster_name}-pcs")
  description = "Security group for ${var.cluster_name} PCS cluster."
  vpc_id      = var.networking.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "PCS API"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  ingress {
    description = "FSx for Lustre"
    from_port   = 988
    to_port     = 988
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "FSx for Lustre"
    from_port   = 1018
    to_port     = 1023
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "EFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Slurm control and data traffic"
    from_port   = 6817
    to_port     = 6818
    protocol    = "tcp"
    self        = true
  }

  tags = merge(var.tags, {
    Name = coalesce(var.security_group_name, "${var.cluster_name}-pcs")
  })
}
