terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.0"
    }
  }
}

provider "aws" {
  region              = "eu-north-1"
  allowed_account_ids = [var.aws_account_id]

  assume_role {
    role_arn     = "arn:aws:iam::${var.aws_account_id}:role/rolename"
    session_name = "terraform_pcs"
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
  region = "eu-north-1"

  assume_role = {
    role_arn     = "arn:aws:iam::${var.aws_account_id}:role/rolename"
    session_name = "terraform_pcs"
  }
}

module "pcs_cluster" {
  source = "git::ssh://git@github.com/wearetechnative/terraform-aws-module-pcs-cluster.git?ref=e57db449189948bcdc16219ec700caa8ac5f8494"

  cluster_name = var.cluster_name

  config = var.config

  networking = var.networking

  instance_profile_name = var.instance_profile_name
  security_group_name   = var.security_group_name
  ingress_cidr_blocks   = var.ingress_cidr_blocks
  kms_key_arn           = var.kms_key_arn
  tags                  = var.tags
}
