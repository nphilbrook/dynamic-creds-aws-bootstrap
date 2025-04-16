locals {
  scope_to_project = var.tf_project_name == "*" ? 0 : 1
}

# Look up the project, if specified
data "tfe_project" "project" {
  count = local.scope_to_project
  name  = var.tf_project_name
}

# Runs with this variable set will be automatically authenticated
# to AWS with the permissions set in the AWS policy.
#
resource "tfe_variable_set" "aws_variable_set" {
  name = var.tf_variable_set_name
}

resource "tfe_project_variable_set" "project_association" {
  count           = local.scope_to_project
  project_id      = data.tfe_project.project[0].id
  variable_set_id = tfe_variable_set.aws_variable_set.id
}

# The following variables must be set to allow runs
# to authenticate to AWS.
#
# https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable
resource "tfe_variable" "enable_aws_provider_auth" {
  variable_set_id = tfe_variable_set.aws_variable_set.id

  key      = "TFC_AWS_PROVIDER_AUTH"
  value    = "true"
  category = "env"

  description = "Enable the Workload Identity integration for AWS."
}

resource "tfe_variable" "tf_aws_role_arn" {
  variable_set_id = tfe_variable_set.aws_variable_set.id

  key      = "TFC_AWS_RUN_ROLE_ARN"
  value    = aws_iam_role.tf_role.arn
  category = "env"

  description = "The AWS role arn runs will use to authenticate."
}

