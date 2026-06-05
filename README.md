# AWS PCS cluster Terraform module

Creates one AWS Parallel Computing Service (PCS) cluster from a JSON-friendly
cluster definition. The module creates launch templates, an optional login
node group, queue compute node groups, and queues.

The caller supplies existing networking, IAM instance profile, AMIs, optional
EFS/FSx for Lustre metadata, and bootstrap template content.

## Usage

```hcl
module "pcs_cluster" {
  source = "git::ssh://git@example.com/terraform-aws-module-pcs-cluster.git?ref=v1.0.0"

  cluster = {
    cluster_name             = "example-pcs"
    pcs_scheduler_version    = "25.05"
    pcs_size                 = "SMALL"
    login_node_instance_type = "t3.small"

    cluster_setup = {
      testqueue1 = {
        computegroup1 = {
          instance_type      = "c5.large"
          min_instance_count = 0
          max_instance_count = 5
          launch_template    = "compute"
        }
        dcvgroup1 = {
          instance_type      = "g4dn.xlarge"
          min_instance_count = 0
          max_instance_count = 2
          launch_template    = "dcv"
          subnet_group       = "public"
        }
      }
    }
  }

  amis = {
    compute = "ami-0123456789abcdef0"
    login   = "ami-0123456789abcdef0"
    dcv     = "ami-0fedcba9876543210"
  }

  bootstrap_scripts = {
    compute = file("${path.module}/bootstrap-compute.init")
    login   = file("${path.module}/bootstrap-login.init")
    dcv     = file("${path.module}/bootstrap-dcv.init")
  }

  filesystems = {
    efs = {
      id = "fs-0123456789abcdef0"
    }
    lustre = {
      id             = "fs-0fedcba9876543210"
      dns_name       = "fs-0fedcba9876543210.fsx.eu-north-1.amazonaws.com"
      mount_name     = "abc123"
      writable_paths = ["/data", "/output"]
    }
  }

  networking = {
    cluster_subnet_ids = [aws_subnet.public_a.id]
    security_group_ids = [aws_security_group.pcs.id]
    node_group_subnet_ids = {
      public  = [aws_subnet.public_a.id, aws_subnet.public_b.id]
      private = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    }
  }

  iam_instance_profile_arn = aws_iam_instance_profile.pcs.arn
  key_name                 = aws_key_pair.pcs.key_name

  launch_template_settings = {
    login = {
      associate_public_ip_address = true
    }
  }
}
```

The `cluster`, `amis`, `filesystems`, and `networking` values are compatible
with JSON `.tfvars` files. The cluster accepts the existing
`cluster_name`/`pcs_scheduler_version`/`pcs_size`/`cluster_setup`/
`login_node_instance_type` naming, plus the generic aliases `name`,
`scheduler_version`, `size`, `queues`, and `login_node`. Queue node groups use
`compute` and `private` by default. The optional login node uses `login` and
`public` by default.

## Bootstrap templates

Each AMI key requires matching bootstrap template content. The module renders
these values into every template:

| Template value | Description |
|---|---|
| `template_efs_id` | EFS file system ID, or an empty string |
| `template_efs_mount_point` | Local EFS mount point, default `/home` |
| `template_lustre_id` | FSx for Lustre file system ID, or an empty string |
| `template_lustre_dns` | FSx for Lustre DNS name, or an empty string |
| `template_lustre_mount_point` | FSx for Lustre mount name, or an empty string |
| `template_lustre_local_path` | Local Lustre mount path, default `/fsx` |
| `template_lustre_writable_paths` | JSON-encoded writable path list |

Shell variables in bootstrap templates must be escaped as `$${VARIABLE}` so
Terraform leaves them intact.

## Requirements

| Name | Version |
|---|---|
| Terraform | >= 1.9.0 |
| AWS provider (`hashicorp/aws`) | >= 5.0.0 |
| AWS Cloud Control provider (`hashicorp/awscc`) | >= 1.0.0 |

The caller must configure both providers in the target AWS region.

## PCS cluster sizes

Choose the cluster size based on both the maximum number of managed instances
and the maximum number of jobs tracked by the Slurm controller.

| Slurm cluster size | Number of instances managed | Number of jobs tracked by the controller |
|---|---:|---:|
| `SMALL` | Up to 32 | Up to 256 |
| `MEDIUM` | Up to 512 | Up to 8,192 |
| `LARGE` | Up to 2,048 | Up to 16,384 |

Examples:

- Up to 24 managed instances and 100 jobs: choose `SMALL`.
- Up to 24 managed instances and 1,000 jobs: choose `MEDIUM`.
- Up to 1,000 managed instances and 100 jobs: choose `LARGE`.
- Up to 1,000 managed instances and 10,000 jobs: choose `LARGE`.

## Outputs

| Name | Description |
|---|---|
| `cluster_id` | PCS cluster ID |
| `cluster` | Full PCS cluster resource |
| `bootstrap_context` | Filesystem values rendered into bootstrap templates |
| `launch_templates` | Full managed launch template resources |
| `launch_template_ids` | Launch template IDs keyed by AMI key |
| `compute_node_group_ids` | Compute node group IDs keyed by derived key |
| `queue_ids` | Queue IDs keyed by queue name |
