# SPDX-License-Identifier: MPL-2.0

# Data source used to grab the TLS certificate for Terraform Cloud.
#
# https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate
data "tls_certificate" "tf_certificate" {
  url = "https://${var.tf_hostname}"
}

# Creates an OIDC provider which is restricted to
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider
resource "aws_iam_openid_connect_provider" "oidc_provider" {
  url             = data.tls_certificate.tf_certificate.url
  client_id_list  = ["aws.workload.identity"]
  thumbprint_list = [data.tls_certificate.tf_certificate.certificates[0].sha1_fingerprint]
}

# Creates a role which can only be used by the specified HCP Terraform project.
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "tf_role" {
  name = "tf-role-${var.tf_organization_name}-${var.tf_project_name}"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Principal": {
       "Federated": "${aws_iam_openid_connect_provider.oidc_provider.arn}"
     },
     "Action": "sts:AssumeRoleWithWebIdentity",
     "Condition": {
       "StringEquals": {
         "${var.tf_hostname}:aud": "${one(aws_iam_openid_connect_provider.oidc_provider.client_id_list)}"
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
  name        = "tf-policy-${var.tf_organization_name}-${var.tf_project_name}"
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
