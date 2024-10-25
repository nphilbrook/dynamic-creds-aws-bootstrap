# SPDX-License-Identifier: MPL-2.0

# variable "tfc_aws_audience" {
#   type        = string
#   default     = "aws.workload.identity"
#   description = "The audience value to use in run identity tokens"
# }

variable "tf_hostname" {
  type        = string
  default     = "app.terraform.io"
  description = "The hostname of the HCP Terraform or TFE instance you'd like to use with AWS"
}

variable "tf_organization_name" {
  type        = string
  description = "The name of your HCP Terraform or TFE organization"
}

variable "tf_project_name" {
  type        = string
  description = "The name of your HCP Terraform or TFE project. Leave the default '*' to enable for any projects in the above organization. If set to non-default, variable set will be scoped to this project as well."
  default     = "*"
}

variable "tf_variable_set_name" {
  type        = string
  description = "The name of the variable set you want to target in which to create AWS dynamic cred variables."
  default     = "Dynamic AWS OIDC WIF credentials"
}
