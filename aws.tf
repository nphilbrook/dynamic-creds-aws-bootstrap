# SPDX-License-Identifier: MPL-2.0

locals {
  # A descriptive suffix for the AWS resources created. If TF project is not specified, omit it.
  aws_suffix = (var.tf_project_name == "*" ?
    "${var.tf_organization_name}" :
  "${var.tf_organization_name}-${var.tf_project_name}")
}

# Data source used to grab the TLS certificate for Terraform Cloud.
#
# https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate
data "tls_certificate" "tf_certificate" {
  url = "https://${var.tf_hostname}"
}

# Checks for an existing OIDC provider for Terraform
#
# NOTE: must have "aws.workload.identity" in the client_id_list. TODO: validate this somehow
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider
data "aws_iam_openid_connect_provider" "existing_oidc_provider" {
  count = var.create_aws_openid_connect_provider ? 0 : 1
  url   = data.tls_certificate.tf_certificate.url
}

# Creates an OIDC provider for Terraform
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider
resource "aws_iam_openid_connect_provider" "oidc_provider" {
  count           = var.create_aws_openid_connect_provider ? 1 : 0
  url             = data.tls_certificate.tf_certificate.url
  client_id_list  = ["aws.workload.identity"]
  thumbprint_list = [data.tls_certificate.tf_certificate.certificates[0].sha1_fingerprint]
}

locals {
  # Convenience local to get either the created, or the existing, OIDC provider ARN 
  oidc_arn = coalescelist(aws_iam_openid_connect_provider.oidc_provider.*.arn,
  data.aws_iam_openid_connect_provider.existing_oidc_provider.*.arn)[0]
}

# Creates a role which can only be used by the specified HCP Terraform project.
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "tf_role" {
  name = "tf-${local.aws_suffix}"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Principal": {
       "Federated": "${local.oidc_arn}"
     },
     "Action": "sts:AssumeRoleWithWebIdentity",
     "Condition": {
       "StringEquals": {
         "${var.tf_hostname}:aud": "aws.workload.identity"
       },
       "StringLike": {
         "${var.tf_hostname}:sub": "organization:${var.tf_organization_name}:project:${var.tf_project_name}:workspace:*:run_phase:*"
       }
     }
   }
 ]
}
EOF
}

# Creates a policy that will be used to define the permissions that
# the previously created role has within AWS.
#
# The Action and Resource blocks in this code should be scoped to your individual use case,
# adhering to the principle fo least privilege. In this example, we'll be dealing with Lambda functions,
# S3 buckets to host the code, and EC2 instances to demonstrate AMI updates coming from Packer builds.
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "tf_policy" {
  name        = "tf-${local.aws_suffix}"
  description = "TFC run policy"

  policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Action": [
       "lambda:*",
       "s3:*",
       "ec2:*"
     ],
     "Resource": "*"
   }
 ]
}
EOF
}

# Creates an attachment to associate the above policy with the
# previously created role.
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "tf_policy_attachment" {
  role       = aws_iam_role.tf_role.name
  policy_arn = aws_iam_policy.tf_policy.arn
}
