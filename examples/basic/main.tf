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
  region = var.aws_region
}

provider "awscc" {
  region = var.aws_region
}

module "pcs_cluster" {
  source = "../.."

  cluster                  = var.cluster
  amis                     = var.amis
  bootstrap_scripts        = var.bootstrap_scripts
  filesystems              = var.filesystems
  networking               = var.networking
  iam_instance_profile_arn = var.iam_instance_profile_arn
  key_name                 = var.key_name
  launch_template_settings = var.launch_template_settings
  tags                     = var.tags
}
