# AWS PCS cluster Terraform module

Creates one AWS Parallel Computing Service (PCS) cluster, the compute/login/DCV
launch templates, a continuously running login node, queue compute node groups,
and queues.

The module keeps the public input close to the existing project tfvars shape.
Bootstrap scripts live inside the module as templates; callers only pass the
filesystem, AMI, scheduler, size, and queue/node-group values.

## Usage

```hcl
module "pcs_cluster" {
  source = "git::ssh://git@example.com/terraform-aws-module-pcs-cluster.git?ref=v1.0.0"

  cluster_name = "prod-pcs"

  config = {
    template_efs_id             = "fs-0e0dba1d074fe7715"
    template_lustre_id          = ""
    template_lustre_dns         = ""
    template_lustre_mount_point = ""

    template_keypair_name     = "technative"
    template_image_id_compute = "ami-06f84c16c5dafab29"
    template_image_id_login   = "ami-06f84c16c5dafab29"
    template_image_id_dcv     = "ami-0d8ff941e94b68531"

    login_node_instance_type = "t3.small"
    pcs_scheduler_version    = "25.05"
    pcs_size                 = "SMALL"

    cluster_setup = {
      testqueue1 = {
        computegroup1 = {
          instance_type      = "c5.large"
          min_instance_count = 0
          max_instance_count = 5
          launch_template    = "compute"
        }
        computegroup2 = {
          instance_type      = "c5.large"
          min_instance_count = 0
          max_instance_count = 5
          launch_template    = "compute"
        }
      }
    }
  }

  networking = {
    vpc_id             = aws_vpc.this.id
    cluster_subnet_ids = [aws_subnet.public_a.id]
    public_subnet_ids  = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    private_subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

    # Optional: place login and DCV nodes in private subnets for VPN-only access.
    # interactive_nodes_public = false
  }

  instance_profile_name = "actiflow"
  security_group_name   = "prod-pcs"
  ingress_cidr_blocks   = ["203.0.113.0/24"]

  tags = {
    Project = "Actiflow"
    Stack   = "pcs"
  }
}
```

`cluster_setup` defines only Slurm queue compute node groups. The login node is
created separately from `login_node_instance_type`.

## Login node

The login node does not need to be defined in `cluster_setup`. The module
creates a separate login compute node group using the login AMI and built-in
login bootstrap template.

By default, the login node group has both its minimum and maximum instance
count set to `1`. This keeps one login node running continuously, independently
of queued Slurm jobs and the scaling configuration of compute node groups.

By default, login and DCV nodes use `networking.public_subnet_ids` and receive
public IPv4 addresses. For VPN-only access, set
`networking.interactive_nodes_public = false`. Login and DCV nodes will then use
`networking.private_subnet_ids` and skip public IPv4 assignment.

## IAM Instance Profile

By default, the module creates the IAM role and instance profile required by
PCS nodes. AWS PCS expects the `AWSPCS` prefix, so the generated names are:

- `AWSPCS-role-${instance_profile_name}`
- `AWSPCS-profile-${instance_profile_name}`

If `instance_profile_name` is not set, `cluster_name` is used as the suffix.
The generated role includes the base PCS permissions and the
`AmazonSSMManagedInstanceCore` managed policy.

Use `kms_key_arn` when the PCS node AMIs or attached resources need KMS decrypt
access. Use `additional_policy_jsons` for project-specific access such as S3
buckets, Route53 records, or application SSM parameters.

If a project already manages IAM separately, pass `iam_instance_profile_arn` to
disable module-managed IAM and use the existing profile.

## Security Group

The module creates one PCS node security group in `networking.vpc_id` and uses
it for the cluster and all launch templates.

The default rules match the current PCS baseline:

| Direction | Port | Source |
|---|---:|---|
| Egress | all | `0.0.0.0/0` |
| Ingress | `8443` | `ingress_cidr_blocks` |
| Ingress | `22` | `ingress_cidr_blocks` |
| Ingress | `988` | self |
| Ingress | `1018-1023` | self |
| Ingress | `2049` | self |
| Ingress | `6817-6818` | self |

`ingress_cidr_blocks` defaults to `["0.0.0.0/0"]` to match the existing stack,
but future projects should usually restrict it.

## Built-In Bootstrap Templates

The module includes these templates:

| Template | Used by |
|---|---|
| `templates/bootstrap-computenodes.init.tftpl` | `compute` launch template |
| `templates/bootstrap-loginnode.init.tftpl` | `login` launch template |
| `templates/bootstrap-dcvnodes.init.tftpl` | `dcv` launch template |

The templates render these config values:

| Config value | Description |
|---|---|
| `template_efs_id` | EFS file system ID. Leave empty to skip EFS mounting. |
| `template_lustre_id` | FSx for Lustre file system ID. |
| `template_lustre_dns` | FSx for Lustre DNS name. Leave empty to skip Lustre mounting. |
| `template_lustre_mount_point` | FSx for Lustre mount name. Leave empty to skip Lustre mounting. |
| `template_lustre_writable_paths` | Optional writable Lustre paths used by the login-node permissions script. |

Shell variables inside the templates are escaped as `$${VARIABLE}` so Terraform
leaves them intact while rendering template values such as `${template_efs_id}`.

The built-in bootstrap templates assume an Amazon Linux compatible AMI. They
expect `cloud-init`, `yum`, and the default `ec2-user` account to be present.
They are not suitable for Ubuntu or other distributions without modification.

## Creating PCS AMIs

The module expects three AMI IDs in `config`:

| Config value | Used by |
|---|---|
| `template_image_id_compute` | queue compute node groups using `launch_template = "compute"` |
| `template_image_id_login` | the always-running login node group |
| `template_image_id_dcv` | queue compute node groups using `launch_template = "dcv"` |

These can point to the same AMI or to different AMIs. For example, compute and
login nodes can usually share an AMI, while DCV nodes often need a separate AMI
with graphical desktop, DCV, GPU, or visualization packages.

AWS PCS can use sample AMIs for testing, but AWS recommends building your own
AMIs for production:

- AWS PCS AMI overview:
  <https://docs.aws.amazon.com/pcs/latest/userguide/working-with_ami.html>
- Custom AMI tutorial:
  <https://docs.aws.amazon.com/pcs/latest/userguide/working-with_ami_custom.html>
- AWS PCS software installers:
  <https://docs.aws.amazon.com/pcs/latest/userguide/working-with_ami_installers.html>

High-level process:

1. Launch a temporary EC2 instance from a supported operating system.
2. Install the AWS PCS agent using the AWS-provided installer.
3. Install a Slurm version compatible with the PCS scheduler version, preferably
   using the AWS-provided Slurm installer.
4. Install extra software needed by that node type:
   - compute: application libraries, MPI/EFA, EFS client, Lustre client
   - login: user tools, EFS client, Lustre client
   - DCV: graphical desktop, DCV packages, GPU/NVIDIA/CUDA packages if needed
5. Create an AMI from the temporary instance.
6. Use the resulting AMI IDs in `template_image_id_compute`,
   `template_image_id_login`, and `template_image_id_dcv`.

AWS PCS currently requires a kernel with IPv4 support for local node
communication, even in IPv6-only networks. The AMI used by each node group must
be compatible with AWS PCS.

After creating or updating an AMI, test it through Slurm instead of only
checking the EC2 instance details. Create or update a small node group, wait for
the login node to complete bootstrap, SSH to the login node, and run:

```bash
sinfo
```

The node group should appear in the Slurm cluster output. If `sinfo` cannot
contact the controller or the nodes do not appear, the AMI or bootstrap process
is not ready for production use.

## PCS Cluster Sizes

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

## Requirements

| Name | Version |
|---|---|
| Terraform | >= 1.9.0 |
| AWS provider (`hashicorp/aws`) | >= 5.0.0 |
| AWS Cloud Control provider (`hashicorp/awscc`) | >= 1.0.0 |

The caller must configure both providers in the target AWS region.

PCS resources are created with the AWS Cloud Control provider because the AWS
provider does not currently expose native PCS resources. Configure `aws` and
`awscc` with the same target account and region.

```hcl
provider "aws" {
  region              = "eu-central-1"
  allowed_account_ids = [var.aws_account_id]

  assume_role {
    role_arn     = "arn:aws:iam::${var.aws_account_id}:role/landing_zone_devops_administrator"
    session_name = "terraform_management_account"
  }

  default_tags {
    tags = {
      Company     = "TechnativeBV"
      IaC_Project = var.project
      Git_URL     = var.git_url
      Stack       = "shared"
    }
  }
}

provider "awscc" {
  region = "eu-central-1"

  assume_role = {
    role_arn     = "arn:aws:iam::${var.aws_account_id}:role/landing_zone_devops_administrator"
    session_name = "terraform_management_account"
  }
}
```

## Inputs

| Name | Description | Required | Default |
|---|---|---:|---|
| `cluster_name` | PCS cluster name. | yes | |
| `config` | PCS config object containing filesystem IDs, AMIs, login instance type, scheduler version, size, and `cluster_setup`. | yes | |
| `networking.vpc_id` | VPC ID where the module-created security group is created. | yes | |
| `networking.cluster_subnet_ids` | Subnets used by the PCS cluster control plane. | yes | |
| `networking.public_subnet_ids` | Subnets used by login and DCV node groups when `interactive_nodes_public` is `true`. | yes | |
| `networking.private_subnet_ids` | Subnets used by compute node groups. | yes | |
| `networking.interactive_nodes_public` | Whether login and DCV node groups use public subnets and receive public IPv4 addresses. | no | `true` |
| `security_group_name` | Name for the module-created PCS security group. | no | `${cluster_name}-pcs` |
| `ingress_cidr_blocks` | CIDRs allowed to reach ports `22` and `8443`. | no | `["0.0.0.0/0"]` |
| `instance_profile_name` | Suffix for `AWSPCS-role-*` and `AWSPCS-profile-*`. | no | `cluster_name` |
| `iam_instance_profile_arn` | Existing instance profile ARN. Supplying this disables module-created IAM. | no | `null` |
| `kms_key_arn` | Optional KMS key ARN for a grant to the module-created PCS role. | no | `null` |
| `additional_policy_jsons` | Extra IAM policy JSON documents attached to the module-created PCS role. | no | `[]` |
| `tags` | Tags applied to module-created resources that support tags. | no | `{}` |

## Outputs

| Name | Description |
|---|---|
| `cluster_id` | PCS cluster ID |
| `cluster` | Full PCS cluster resource |
| `bootstrap_context` | Values rendered into the built-in bootstrap templates |
| `launch_templates` | Full managed launch template resources |
| `launch_template_ids` | Launch template IDs keyed by `compute`, `login`, and `dcv` |
| `compute_node_group_ids` | Compute node group IDs keyed by derived key |
| `queue_ids` | Queue IDs keyed by queue name |
| `iam_instance_profile_arn` | IAM instance profile ARN used by PCS node groups |
| `iam_role_arn` | Module-created IAM role ARN, or `null` when an existing profile is supplied |
| `security_group_ids` | Security group IDs used by the PCS cluster and nodes |
