resource "aws_iam_role" "pcs" {
  count = local.create_instance_profile ? 1 : 0

  name                  = "AWSPCS-role-${local.instance_profile_name}"
  path                  = "/aws-pcs/"
  force_detach_policies = true
  assume_role_policy    = data.aws_iam_policy_document.pcs_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "pcs_ssm_core" {
  count = local.create_instance_profile ? 1 : 0

  role       = aws_iam_role.pcs[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "pcs" {
  count = local.create_instance_profile ? 1 : 0

  name = "AWSPCS-profile-${local.instance_profile_name}"
  role = aws_iam_role.pcs[0].name

  tags = var.tags
}

resource "aws_iam_role_policy" "pcs" {
  count = local.create_instance_profile ? 1 : 0

  name   = "pcs-policy-${local.instance_profile_name}"
  role   = aws_iam_role.pcs[0].id
  policy = data.aws_iam_policy_document.pcs.json
}

resource "aws_iam_role_policy" "additional" {
  count = local.create_instance_profile ? length(var.additional_policy_jsons) : 0

  name   = "pcs-additional-${local.instance_profile_name}-${count.index}"
  role   = aws_iam_role.pcs[0].id
  policy = var.additional_policy_jsons[count.index]
}

resource "aws_kms_grant" "pcs" {
  count = local.create_instance_profile && var.kms_key_arn != null ? 1 : 0

  name              = "pcs-${local.instance_profile_name}"
  key_id            = var.kms_key_arn
  grantee_principal = aws_iam_role.pcs[0].arn
  operations        = ["Decrypt", "GenerateDataKey"]
}

data "aws_iam_policy_document" "pcs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "pcs" {
  statement {
    sid    = "PermissionsToRegisterComputeNodeGroupInstance"
    effect = "Allow"
    actions = [
      "pcs:RegisterComputeNodeGroupInstance",
      "pcs:GetComputeNodeGroup"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PermissionsToCreatePCSNetworkInterfaces"
    effect    = "Allow"
    actions   = ["ec2:CreateNetworkInterface"]
    resources = ["arn:aws:ec2:*:*:network-interface/*"]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/AWSPCSManaged"
      values   = ["false"]
    }
  }

  statement {
    sid     = "PermissionsToCreatePCSNetworkInterfacesInSubnet"
    effect  = "Allow"
    actions = ["ec2:CreateNetworkInterface"]
    resources = [
      "arn:aws:ec2:*:*:subnet/*",
      "arn:aws:ec2:*:*:security-group/*"
    ]
  }

  statement {
    sid    = "PermissionsToManagePCSNetworkInterfaces"
    effect = "Allow"
    actions = [
      "ec2:DeleteNetworkInterface",
      "ec2:CreateNetworkInterfacePermission"
    ]
    resources = ["arn:aws:ec2:*:*:network-interface/*"]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/AWSPCSManaged"
      values   = ["false"]
    }
  }

  statement {
    sid    = "PermissionsToDescribePCSResources"
    effect = "Allow"
    actions = [
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstanceAttribute",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeImages",
      "ec2:DescribeImageAttribute"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PermissionsToCreatePCSLaunchTemplates"
    effect    = "Allow"
    actions   = ["ec2:CreateLaunchTemplate"]
    resources = ["arn:aws:ec2:*:*:launch-template/*"]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/AWSPCSManaged"
      values   = ["false"]
    }
  }

  statement {
    sid    = "PermissionsToManagePCSLaunchTemplates"
    effect = "Allow"
    actions = [
      "ec2:DeleteLaunchTemplate",
      "ec2:DeleteLaunchTemplateVersions",
      "ec2:CreateLaunchTemplateVersion"
    ]
    resources = ["arn:aws:ec2:*:*:launch-template/*"]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/AWSPCSManaged"
      values   = ["false"]
    }
  }

  statement {
    sid       = "PermissionsToTerminatePCSManagedInstances"
    effect    = "Allow"
    actions   = ["ec2:TerminateInstances"]
    resources = ["arn:aws:ec2:*:*:instance/*"]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/AWSPCSManaged"
      values   = ["false"]
    }
  }

  statement {
    sid     = "PermissionsToPassRoleToEC2"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::*:role/*/AWSPCS*",
      "arn:aws:iam::*:role/AWSPCS*",
      "arn:aws:iam::*:role/aws-pcs/*",
      "arn:aws:iam::*:role/*/aws-pcs/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid    = "PermissionsToControlClusterInstanceAttributes"
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet"
    ]
    resources = [
      "arn:aws:ec2:*::image/*",
      "arn:aws:ec2:*::snapshot/*",
      "arn:aws:ec2:*:*:subnet/*",
      "arn:aws:ec2:*:*:network-interface/*",
      "arn:aws:ec2:*:*:security-group/*",
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:key-pair/*",
      "arn:aws:ec2:*:*:launch-template/*",
      "arn:aws:ec2:*:*:placement-group/*",
      "arn:aws:ec2:*:*:capacity-reservation/*",
      "arn:aws:resource-groups:*:*:group/*",
      "arn:aws:ec2:*:*:fleet/*",
      "arn:aws:ec2:*:*:spot-instances-request/*"
    ]
  }

  statement {
    sid    = "PermissionsToProvisionClusterInstances"
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet"
    ]
    resources = ["arn:aws:ec2:*:*:instance/*"]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/AWSPCSManaged"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowEfsDescribe"
    effect = "Allow"
    actions = [
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeMountTargets",
      "elasticfilesystem:DescribeMountTargetSecurityGroups",
      "elasticfilesystem:DescribeAccessPoints"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "PermissionsToTagPCSResources"
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DescribeTags"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PermissionsToPublishMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["AWS/PCS"]
    }
  }

  statement {
    sid    = "PermissionsToManageSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecretVersionStage",
      "secretsmanager:DeleteSecret"
    ]
    resources = ["arn:aws:secretsmanager:*:*:secret:pcs!*"]

    condition {
      test     = "StringEquals"
      variable = "secretsmanager:ResourceTag/aws:secretsmanager:owningService"
      values   = ["pcs"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = ["$${aws:PrincipalAccount}"]
    }
  }
}
